use crate::{config::CONFIG, orm::mapcache::record::MapRecord, transport::Channel};
use chrono::{DateTime, Utc};
use serde::Serialize;
use serde_repr::Serialize_repr;

use super::{
    events::game::GameEvent,
    map::GameMap,
    models::{
        self,
        livegame::MapClaim,
        player::Player,
        room::RoomTeam,
        team::{BaseTeam, TeamIdentifier},
    },
    util::base64,
};

pub type MatchConfiguration = models::livegame::MatchConfiguration;

pub struct LiveMatch {
    uid: String,
    config: MatchConfiguration,
    teams: Vec<GameTeam>,
    cells: Vec<GameCell>,
    started: DateTime<Utc>,
    channel: Channel<GameEvent>,
}

impl LiveMatch {
    pub fn new(
        config: MatchConfiguration,
        maps: Vec<MapRecord>,
        teams: Vec<GameTeam>,
        start_date: DateTime<Utc>,
        channel: Option<Channel<GameEvent>>,
    ) -> Self {
        let channel = channel.unwrap_or_else(Channel::new);

        Self {
            uid: base64::generate(16),
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
            channel,
        }
    }

    pub fn broadcast_start(&mut self) {
        self.channel.broadcast(&GameEvent::MatchStart {
            start_ms: CONFIG.game.start_countdown,
            maps: self.cells.iter().map(|c| c.map.record.clone()).collect(),
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
        let i = 0;
        while i < ranking.len() {
            let current = &ranking[i];
            if current.player == claim.player {
                ranking.remove(i);
                continue;
            }
            if claim.time < current.time {
                break;
            }
        }
        ranking.insert(i, claim.clone());
        self.broadcast_submitted_run(id, claim, i + 1);
    }

    fn broadcast_submitted_run(&mut self, cell_id: usize, claim: MapClaim, position: usize) {
        self.channel.broadcast(&GameEvent::RunSubmitted {
            cell_id,
            claim,
            position,
        })
    }

    pub fn check_for_bingos(&self, grid_size: usize) -> Vec<BingoLine> {
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

            let col = iter.step_by(grid_size);
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
}

pub struct GameTeam {
    base: BaseTeam,
    members: Vec<Player>,
}

impl From<RoomTeam> for GameTeam {
    fn from(value: RoomTeam) -> Self {
        Self {
            base: value.base,
            members: value.members,
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
