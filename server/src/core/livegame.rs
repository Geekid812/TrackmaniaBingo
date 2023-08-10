use std::sync::{Arc, Weak};

use crate::{
    config::CONFIG,
    orm::{
        self,
        mapcache::record::MapRecord,
        models::matches::{Match, PlayerToMatch},
    },
    server::tasks::execute_delayed_task,
    transport::Channel,
};
use chrono::{DateTime, Duration, Utc};
use diesel::{insert_into, RunQueryDsl};
use parking_lot::Mutex;
use serde::Serialize;
use serde_repr::Serialize_repr;
use tracing::error;

use super::{
    directory::{Owned, Shared},
    events::game::GameEvent,
    map::GameMap,
    models::{
        self,
        livegame::{MapClaim, MatchPhase},
        player::Player,
        room::RoomTeam,
        team::{BaseTeam, TeamIdentifier},
    },
    room::GameRoom,
    util::base64,
};

pub type MatchConfiguration = models::livegame::MatchConfiguration;

pub struct LiveMatch {
    ptr: Shared<Self>,
    uid: String,
    room: Shared<GameRoom>,
    config: MatchConfiguration,
    teams: Vec<GameTeam>,
    cells: Vec<GameCell>,
    started: DateTime<Utc>,
    phase: MatchPhase,
    channel: Channel<GameEvent>,
}

impl LiveMatch {
    pub fn new(
        room: Shared<GameRoom>,
        config: MatchConfiguration,
        maps: Vec<MapRecord>,
        teams: Vec<GameTeam>,
        start_date: DateTime<Utc>,
        channel: Option<Channel<GameEvent>>,
    ) -> Owned<Self> {
        let channel = channel.unwrap_or_else(Channel::new);

        let mut _self = Self {
            ptr: Weak::new(),
            uid: base64::generate(16),
            room,
            config,
            teams,
            cells: maps
                .into_iter()
                .map(|map| GameCell {
                    map: GameMap::from(map),
                    claims: Vec::new(),
                })
                .collect(),
            started: start_date,
            phase: MatchPhase::Starting,
            channel,
        };
        let arc = Arc::new(Mutex::new(_self));
        arc.lock().ptr = Arc::downgrade(&arc);
        arc
    }

    pub fn setup_match_start(&mut self) {
        self.setup_phase_timers();
        self.broadcast_start();
    }

    fn setup_phase_timers(&mut self) {
        let mut first_phase = MatchPhase::Running;
        let countdown_duration = CONFIG.game.start_countdown;
        let nobingo_duration = Duration::minutes(self.config.no_bingo_mins as i64);
        let main_phase_duration = Duration::minutes(self.config.time_limit as i64);
        if !nobingo_duration.is_zero() {
            first_phase = MatchPhase::NoBingo;
            execute_delayed_task(
                self.ptr.clone(),
                |game| game.nobingo_phase_change(),
                (countdown_duration + nobingo_duration).to_std().unwrap(),
            );
        }
        if !main_phase_duration.is_zero() {
            execute_delayed_task(
                self.ptr.clone(),
                |game| game.overtime_phase_change(),
                (countdown_duration + nobingo_duration + main_phase_duration)
                    .to_std()
                    .unwrap(),
            );
        }
        execute_delayed_task(
            self.ptr.clone(),
            move |game| game.set_phase(first_phase),
            countdown_duration.to_std().unwrap(),
        );
    }

    fn set_phase(&mut self, phase: MatchPhase) {
        self.phase = phase;
        self.channel.broadcast(&GameEvent::PhaseChange { phase });
    }

    fn broadcast_start(&mut self) {
        let maps_in_grid = self.config.grid_size * self.config.grid_size;
        self.channel.broadcast(&GameEvent::MatchStart {
            start_ms: CONFIG.game.start_countdown,
            maps: self
                .cells
                .iter()
                .take(maps_in_grid)
                .map(|c| c.map.record.clone())
                .collect(),
        });
    }

    pub fn uid(&self) -> &String {
        &self.uid
    }

    pub fn config(&self) -> &MatchConfiguration {
        &self.config
    }

    pub fn get_player_team(&self, player_id: i32) -> Option<TeamIdentifier> {
        for team in &self.teams {
            if team
                .members
                .iter()
                .filter(|p| p.profile.player.uid == player_id)
                .next()
                .is_some()
            {
                return Some(team.base.id);
            }
        }

        return None;
    }

    pub fn get_cell(&self, id: usize) -> &GameCell {
        &self.cells[id]
    }

    pub fn get_team_mut(&mut self, team_id: TeamIdentifier) -> Option<&mut GameTeam> {
        self.teams
            .iter_mut()
            .filter(|t| t.base.id == team_id)
            .next()
    }

    pub fn start_date(&self) -> &DateTime<Utc> {
        &self.started
    }

    pub fn get_cell_from_map_uid(&self, uid: String) -> Option<usize> {
        self.cells
            .iter()
            .enumerate()
            .filter(|(_, c)| c.map.record.uid == uid)
            .map(|(i, _)| i)
            .next()
    }

    pub fn add_submitted_run(&mut self, id: usize, claim: MapClaim) {
        let ranking = &mut self.cells[id].claims;

        // Bubble up in the ranking until we find a time that was not beaten
        let mut i = ranking.len();
        while i > 0 {
            let current = &ranking[i - 1];
            if current.player == claim.player {
                ranking.remove(i - 1);
            } else if claim.time >= current.time {
                break;
            }
            i -= 1;
        }
        ranking.insert(i, claim.clone());
        self.broadcast_submitted_run(id, claim, i + 1);

        self.do_bingo_checks();
    }

    fn announce_bingo_and_game_end(&mut self, line: BingoLine) {
        let winning_team = self.get_team_mut(line.team).expect("winning team exists");
        winning_team.winner = true;

        self.channel
            .broadcast(&GameEvent::AnnounceBingo { line: line.clone() });
        self.set_game_ended();
    }

    fn set_game_ended(&mut self) {
        if let Some(room) = self.room.upgrade() {
            room.lock().reset_match();
        }
        self.save_match();
    }

    fn save_match(&mut self) {
        let match_model = Match {
            uid: self.uid.clone(),
            started_at: self.started.naive_utc(),
            ended_at: Utc::now().naive_utc(),
        };
        let mut player_results = Vec::new();
        for team in &self.teams {
            for player in &team.members {
                player_results.push(PlayerToMatch {
                    player_uid: player.profile.player.uid,
                    match_uid: self.uid.clone(),
                    outcome: if team.winner {
                        "W".to_owned()
                    } else {
                        "L".to_owned()
                    },
                });
            }
        }
        tokio::spawn(orm::execute(move |conn| {
            use crate::orm::schema::{
                matches::dsl::matches, matches_players::dsl::matches_players,
            };
            if let Err(e) = insert_into(matches).values(match_model).execute(conn) {
                error!("execute error: {}", e);
            }
            if let Err(e) = insert_into(matches_players)
                .values(player_results)
                .execute(conn)
            {
                error!("execute error: {}", e);
            }
        }));
    }

    fn broadcast_submitted_run(&mut self, cell_id: usize, claim: MapClaim, position: usize) {
        self.channel.broadcast(&GameEvent::RunSubmitted {
            cell_id,
            claim,
            position,
        })
    }

    fn do_bingo_checks(&mut self) -> bool {
        if self.phase != MatchPhase::NoBingo {
            let bingos = self.check_for_bingos();
            let len = bingos.len();
            if len > 1 && !bingos.iter().all(|line| line.team == bingos[0].team) {
                self.overtime_phase_change();
            } else if len >= 1 {
                let bingo_line = bingos[0].clone();
                self.announce_bingo_and_game_end(bingo_line);
                return true;
            }
        }
        false
    }

    pub fn check_for_bingos(&self) -> Vec<BingoLine> {
        let grid_size = self.config.grid_size;
        let mut bingos = Vec::new();
        // Horizontal
        for i in 0..grid_size {
            let line = self.cells[i * grid_size..(i + 1) * grid_size]
                .iter()
                .take(grid_size);

            let unique_team = iter_check_unique_team(line);

            if let Some(team) = unique_team {
                bingos.push(BingoLine {
                    direction: Direction::Horizontal,
                    index: i as u32,
                    team,
                });
            }
        }

        // Vertical
        for i in 0..grid_size {
            let mut iter = self.cells.iter();

            // Advance by i items to align column
            for _ in 0..i {
                iter.next();
            }

            let col = iter.step_by(grid_size).take(grid_size);
            let unique_team = iter_check_unique_team(col);

            if let Some(team) = unique_team {
                bingos.push(BingoLine {
                    direction: Direction::Vertical,
                    index: i as u32,
                    team,
                });
            }
        }

        // Diagonal
        let mut diag0 = Vec::with_capacity(grid_size);
        let mut diag1 = Vec::with_capacity(grid_size);

        for i in 0..grid_size {
            diag0.push(self.cells.get(i * grid_size + i).unwrap());
            diag1.push(self.cells.get((grid_size - 1) * (i + 1)).unwrap());
        }

        let unique_team0 = iter_check_unique_team(diag0.into_iter());
        let unique_team1 = iter_check_unique_team(diag1.into_iter());

        if let Some(team) = unique_team0 {
            bingos.push(BingoLine {
                direction: Direction::Diagonal,
                index: 0,
                team,
            });
        }

        if let Some(team) = unique_team1 {
            bingos.push(BingoLine {
                direction: Direction::Diagonal,
                index: 1,
                team,
            });
        }

        bingos
    }

    fn nobingo_phase_change(&mut self) {
        if !self.do_bingo_checks() && self.phase != MatchPhase::Overtime {
            self.set_phase(MatchPhase::Running);
        }
    }

    fn overtime_phase_change(&mut self) {
        self.set_phase(MatchPhase::Overtime);
    }
}

pub struct GameTeam {
    base: BaseTeam,
    members: Vec<Player>,
    pub winner: bool,
}

impl From<RoomTeam> for GameTeam {
    fn from(value: RoomTeam) -> Self {
        Self {
            base: value.base,
            members: value.members,
            winner: false,
        }
    }
}

pub struct GameCell {
    pub map: GameMap,
    pub claims: Vec<MapClaim>,
}

impl GameCell {
    pub fn leading_claim(&self) -> Option<&MapClaim> {
        self.claims.iter().next()
    }
}

#[derive(Serialize, Clone)]
pub struct BingoLine {
    pub direction: Direction,
    pub index: u32,
    pub team: TeamIdentifier,
}

#[derive(Serialize_repr, Clone, Copy)]
#[repr(u32)]
pub enum Direction {
    None = 0,
    Horizontal = 1,
    Vertical = 2,
    Diagonal = 3,
}

fn iter_check_unique_team<'a>(
    mut iter: impl Iterator<Item = &'a GameCell>,
) -> Option<TeamIdentifier> {
    let first = iter
        .next()
        .expect("invalid grid_size")
        .leading_claim()
        .as_ref()
        .map(|c| c.player.team);
    iter.fold(first, |acc, x| {
        acc.and_then(|y| {
            if x.leading_claim().as_ref().map(|c| c.player.team) == Some(y) {
                Some(y)
            } else {
                None
            }
        })
    })
}
