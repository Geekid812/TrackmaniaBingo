use anyhow::anyhow;
use std::{
    collections::HashMap,
    sync::{Arc, Weak},
};

use crate::{
    config::CONFIG,
    datatypes::{CampaignMap, MatchConfiguration, PlayerRef, Poll, PollChoice},
    server::{context::ClientContext, tasks::execute_delayed_task},
    store::{
        self,
        matches::{Match, MatchOutcome, MatchResult},
    },
    transport::Channel,
};
use chrono::{DateTime, Duration, Utc};
use parking_lot::Mutex;
use serde::Serialize;
use serde_repr::Serialize_repr;
use tracing::{debug, error, warn};

use super::{
    directory::{Owned, Shared, MATCHES},
    events::game::GameEvent,
    gamecommon::PlayerId,
    models::{
        livegame::{GameCell, MapClaim, MatchPhase, MatchState},
        map::GameMap,
        player::Player,
        team::{GameTeam, TeamIdentifier},
    },
    room::GameRoom,
    teams::TeamsManager,
    util::{base64, Color},
};

pub struct LiveMatch {
    ptr: Shared<Self>,
    uid: String,
    room: Shared<GameRoom>,
    config: MatchConfiguration,
    options: MatchOptions,
    teams: TeamsManager<GameTeam>,
    cells: Vec<GameCell>,
    started: Option<DateTime<Utc>>,
    phase: MatchPhase,
    channel: Channel<GameEvent>,
    polls: HashMap<u32, Owned<PollData>>,
}

struct MatchOptions {
    start_countdown: Duration,
}

struct PollData {
    pub poll: Poll,
    pub votes: Vec<Vec<PlayerId>>,
    pub callback: PollResultCallback,
}

pub enum PollResultCallback {
    None,
    Reroll(usize),
}

impl LiveMatch {
    pub fn new(
        config: MatchConfiguration,
        maps: Vec<GameMap>,
        teams: TeamsManager<GameTeam>,
    ) -> Owned<Self> {
        let mut _self = Self {
            ptr: Weak::new(),
            uid: base64::generate(16),
            room: Weak::new(),
            config,
            options: MatchOptions::default(),
            teams,
            cells: maps
                .into_iter()
                .map(|map| GameCell {
                    map,
                    claims: Vec::new(),
                    reroll_ids: Vec::new(),
                })
                .collect(),
            started: None,
            phase: MatchPhase::Starting,
            channel: Channel::new(),
            polls: HashMap::new(),
        };
        let arc = Arc::new(Mutex::new(_self));
        arc.lock().ptr = Arc::downgrade(&arc);
        arc
    }

    pub fn set_parent_room(&mut self, room: Shared<GameRoom>) {
        self.room = room;
    }

    pub fn set_channel(&mut self, channel: Channel<GameEvent>) {
        self.channel = channel;
    }

    pub fn set_start_countdown(&mut self, countdown: Duration) {
        if self.started.is_some() {
            panic!("attempted to change match options after starting");
        }
        self.options.start_countdown = countdown;
    }

    pub fn setup_match_start(&mut self, start_date: DateTime<Utc>) {
        self.started = Some(start_date);
        self.setup_phase_timers();
        self.broadcast_start();
    }

    fn setup_phase_timers(&mut self) {
        let mut first_phase = MatchPhase::Running;
        let countdown_duration = self.options.start_countdown;
        let nobingo_duration = self.config.no_bingo_duration;
        let main_phase_duration = self.config.time_limit;
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
                |game| game.endgame_phase_change(),
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
        let maps_in_grid = self.cell_count();
        self.channel.broadcast(&GameEvent::MatchStart {
            uid: self.uid().clone(),
            start_ms: self.options.start_countdown,
            maps: self
                .cells
                .iter()
                .take(maps_in_grid)
                .map(|c| c.map.clone())
                .collect(),
            can_reroll: self.can_reroll(),
        });
    }

    pub fn uid(&self) -> &String {
        &self.uid
    }

    pub fn config(&self) -> &MatchConfiguration {
        &self.config
    }

    pub fn channel(&mut self) -> &mut Channel<GameEvent> {
        &mut self.channel
    }

    pub fn can_reroll(&self) -> bool {
        self.config.rerolls && self.cells.len() > self.cell_count()
    }

    pub fn get_player_team(&self, player_id: i32) -> Option<TeamIdentifier> {
        for team in self.teams.get_teams() {
            if team
                .members
                .iter()
                .filter(|p| p.profile.uid == player_id)
                .next()
                .is_some()
            {
                return Some(team.base.id);
            }
        }

        return None;
    }

    fn get_least_populated_team(&self) -> Option<&GameTeam> {
        self.teams
            .get_teams()
            .iter()
            .min_by_key(|team| team.members.iter().count())
    }

    pub fn player_join(
        &mut self,
        ctx: &ClientContext,
        mut requested_team: Option<TeamIdentifier>,
    ) -> Result<TeamIdentifier, anyhow::Error> {
        let already_joined_team = self.get_player_team(ctx.profile.uid);

        if let Some(team) = already_joined_team {
            self.channel.subscribe(ctx.profile.uid, ctx.writer.clone());
            return Ok(team);
        } else {
            if !self.config.late_join {
                return Err(anyhow!("late joining is disabled for this match"));
            }

            if requested_team.is_none() {
                requested_team = self.get_least_populated_team().map(|t| t.base.id);
            }
        }

        let team = self.add_player(ctx, requested_team)?;
        Ok(team)
    }

    fn add_player(
        &mut self,
        ctx: &ClientContext,
        team: Option<TeamIdentifier>,
    ) -> Result<TeamIdentifier, anyhow::Error> {
        let team = match team {
            Some(id) => self
                .teams
                .get_mut(id)
                .ok_or(anyhow!("team id {:?} not found", id))?,
            None => {
                let id = self
                    .teams
                    .create_random_team(ctx.profile.name.clone())
                    .base
                    .id;
                let team = self
                    .teams
                    .get_mut(id)
                    .expect("team exists after creating it");
                self.channel.broadcast(&GameEvent::MatchTeamCreated {
                    base: team.base.clone(),
                });
                team
            }
        };

        team.members.push(Player {
            profile: ctx.profile.clone(),
            operator: false,
            disconnected: false,
        });
        self.channel.subscribe(ctx.profile.uid, ctx.writer.clone());
        self.channel.broadcast(&GameEvent::MatchPlayerJoin {
            profile: ctx.profile.clone(),
            team: team.base.id,
        });
        Ok(team.base.id)
    }

    pub fn get_cell(&self, id: usize) -> &GameCell {
        &self.cells[id]
    }

    pub fn get_team_mut(&mut self, team_id: TeamIdentifier) -> Option<&mut GameTeam> {
        self.teams.get_mut(team_id)
    }

    pub fn start_date(&self) -> &Option<DateTime<Utc>> {
        &self.started
    }

    pub fn playstart_date(&self) -> Option<DateTime<Utc>> {
        self.started
            .as_ref()
            .map(|d| *d + self.options.start_countdown)
    }

    pub fn get_cell_from_map_uid(&self, uid: String) -> Option<usize> {
        self.cells
            .iter()
            .enumerate()
            .filter(|(_, c)| {
                if let GameMap::TMX(record) = &c.map {
                    return record.uid == uid;
                } else {
                    return false;
                }
            })
            .map(|(i, _)| i)
            .next()
    }

    pub fn get_cell_from_campaign(&self, campaign: &CampaignMap) -> Option<usize> {
        self.cells
            .iter()
            .enumerate()
            .filter(|(_, c)| {
                if let GameMap::Campaign(campaign_other) = &c.map {
                    return campaign == campaign_other;
                } else {
                    return false;
                }
            })
            .map(|(i, _)| i)
            .next()
    }

    pub fn get_state(&self) -> MatchState {
        MatchState {
            uid: self.uid.clone(),
            config: self.config.clone(),
            phase: self.phase,
            teams: self.teams.get_teams().iter().map(GameTeam::clone).collect(),
            cells: self
                .cells
                .iter()
                .take(self.cell_count())
                .map(Clone::clone)
                .collect(),
            started: self.started.unwrap_or_default(),
            can_reroll: self.can_reroll(),
        }
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

        if self.try_do_bingo_checks() {
            return;
        }
        if self.phase == MatchPhase::Overtime {
            self.do_cell_winner_checks();
        }
    }

    fn announce_bingo_and_game_end(&mut self, lines: Vec<BingoLine>) {
        for line in &lines {
            let winning_team = self.get_team_mut(line.team).expect("winning team exists");
            winning_team.winner = true;
        }

        self.channel.broadcast(&GameEvent::AnnounceBingo {
            lines: lines.clone(),
        });
        self.set_game_ended(false);
    }

    fn set_game_ended(&mut self, draw: bool) {
        if let Some(room) = self.room.upgrade() {
            room.lock().reset_match();
        }

        if self.should_match_be_saved() {
            self.save_match_end(draw);
        }

        MATCHES.remove(self.uid.clone());
    }

    fn should_match_be_saved(&self) -> bool {
        // Save match results if there are at least 2 players
        self.player_count() >= 2
    }

    fn cell_count(&self) -> usize {
        self.config.grid_size as usize * self.config.grid_size as usize
    }

    fn player_count(&self) -> usize {
        self.teams.get_teams().iter().map(|t| t.members.len()).sum()
    }

    fn save_match_end(&mut self, draw: bool) {
        let match_model = Match {
            uid: self.uid.clone(),
            started_at: self.started.unwrap_or_default(),
            ended_at: Utc::now(),
        };
        let mut player_results = Vec::new();
        for team in self.teams.get_teams() {
            for player in &team.members {
                player_results.push((
                    player.profile.uid,
                    if draw {
                        MatchOutcome::Draw
                    } else if team.winner {
                        MatchOutcome::Win
                    } else {
                        MatchOutcome::Loss
                    },
                ));
            }
        }
        tokio::spawn(store::matches::write_match_end(
            match_model,
            MatchResult(player_results),
        ));
    }

    fn broadcast_submitted_run(&mut self, cell_id: usize, claim: MapClaim, position: usize) {
        self.channel.broadcast(&GameEvent::RunSubmitted {
            cell_id,
            claim,
            position,
        })
    }

    pub fn submit_reroll_vote(
        &mut self,
        cell_id: usize,
        player: PlayerRef,
    ) -> Result<(), anyhow::Error> {
        if !self.config.rerolls {
            return Err(anyhow!("rerolls are disabled for this match"));
        }
        if cell_id >= self.cell_count() {
            return Err(anyhow!(
                "invalid cell_id {}, max is {}",
                cell_id,
                self.cell_count() - 1
            ));
        }

        let poll_id = 0x10000 | cell_id as u32;
        let already_voting = self.polls.contains_key(&poll_id);
        if already_voting {
            return Err(anyhow!("there is already a reroll vote for this map"));
        }

        let cell = &self.cells[cell_id];
        let poll = Poll {
            id: poll_id,
            title: format!(
                "{} asks: Reroll \\$ff8{}\\$z?",
                player.name,
                cell.map.name()
            ),
            color: Color::new(128, 128, 128),
            duration: Duration::seconds(60),
            choices: vec![
                PollChoice {
                    text: "Yes".to_string(),
                    color: Color::new(0, 100, 0),
                },
                PollChoice {
                    text: "No".to_string(),
                    color: Color::new(100, 0, 0),
                },
            ],
        };

        let initial_votes = vec![vec![player.uid], Vec::new()];
        self.start_poll(poll, initial_votes, PollResultCallback::Reroll(cell_id));

        Ok(())
    }

    fn reroll_map(&mut self, cell_id: usize) -> Result<(), anyhow::Error> {
        if !self.can_reroll() {
            return Err(anyhow!("tried to reroll, but rerolls are disallowed"));
        }
        if self.cells[cell_id].leading_claim().is_some() {
            return Err(anyhow!("map is already claimed, cannot reroll it"));
        }

        self.cells.swap_remove(cell_id);
        self.channel.broadcast(&GameEvent::MapRerolled {
            cell_id,
            map: self.cells[cell_id].map.clone(),
            can_reroll: self.can_reroll(),
        });
        Ok(())
    }

    fn try_do_bingo_checks(&mut self) -> bool {
        if self.phase != MatchPhase::NoBingo {
            return self.run_bingo_checks();
        }
        false
    }

    fn run_bingo_checks(&mut self) -> bool {
        let bingos = self.check_for_bingos();
        let len = bingos.len();
        if len >= 1 && bingos.iter().all(|line| line.team == bingos[0].team) {
            self.announce_bingo_and_game_end(bingos);
            return true;
        }
        false
    }

    pub fn check_for_bingos(&self) -> Vec<BingoLine> {
        let grid_size = self.config.grid_size as usize;
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

    pub fn do_cell_winner_checks(&mut self) -> bool {
        if let Some(winning_team) = self.get_winning_team_by_cell_count() {
            self.teams
                .get_mut(winning_team)
                .expect("winning team exists")
                .winner = true;
            self.channel
                .broadcast(&GameEvent::AnnounceWinByCellCount { team: winning_team });
            self.set_game_ended(false);
            return true;
        }
        false
    }

    fn get_winning_team_by_cell_count(&self) -> Option<TeamIdentifier> {
        let mut winner = None;
        let mut max_score = 0;
        let iter = self.cells.iter().take(self.cell_count());
        for team in self.teams.get_teams() {
            let score = iter
                .clone()
                .filter(|cell| {
                    cell.leading_claim().is_some()
                        && cell.leading_claim().unwrap().team_id == team.base.id
                })
                .count();
            if score > max_score {
                max_score = score;
                winner = Some(team.base.id);
            } else if score == max_score {
                winner = None;
            }
        }

        winner
    }

    pub fn start_poll(
        &mut self,
        poll: Poll,
        initial_votes: Vec<Vec<PlayerId>>,
        callback: PollResultCallback,
    ) {
        let poll_id = poll.id;
        let delay = poll.duration.to_std().unwrap();
        let votes_count = initial_votes.iter().map(|v| v.len() as i32).collect();

        let event = GameEvent::PollStart {
            poll: poll.clone(),
            votes: votes_count,
        };
        let poll_data = Arc::new(Mutex::new(PollData {
            poll,
            votes: initial_votes,
            callback,
        }));
        let poll_ref = Arc::downgrade(&poll_data);
        self.polls.insert(poll_id, poll_data);

        execute_delayed_task(
            self.ptr.clone(),
            move |_self| LiveMatch::poll_end(_self, poll_ref),
            delay,
        );
        self.channel.broadcast(&event);
    }

    pub fn poll_cast_vote(&mut self, poll_id: u32, uid: u32, choice: usize) {
        let Some(poll) = self.polls.get(&poll_id) else {
            return;
        };

        let mut lock = poll.lock();
        let votes = &mut lock.votes;

        for i in 0..votes.len() {
            if i == choice {
                if !votes[i].contains(&uid) {
                    votes[i].push(uid);
                }
            } else if let Some(idx) = votes[i].iter().position(|x| *x == uid) {
                votes[i].remove(idx);
            }
        }

        let event = GameEvent::PollVotesUpdate {
            id: poll_id,
            votes: votes.iter().map(|v| v.len() as i32).collect(),
        };
        self.channel.broadcast(&event);
    }

    fn poll_end(&mut self, poll_ref: Shared<PollData>) {
        if let Some(lock) = poll_ref.upgrade() {
            let poll = lock.lock();
            let (selected_choice, _) = poll
                .votes
                .iter()
                .enumerate()
                .max_by_key(|(_i, v)| v.len())
                .expect("expected at least one choice");

            self.channel.broadcast(&GameEvent::PollResult {
                id: poll.poll.id,
                selected: Some(selected_choice as u32),
            });

            match poll.callback {
                PollResultCallback::Reroll(cell_id)
                    if poll.votes[0].len() > poll.votes[1].len() =>
                {
                    if let Err(e) = self.reroll_map(cell_id) {
                        error!("{}", e);
                    }
                }
                _ => (),
            };
            self.polls.remove(&poll.poll.id);
        } else {
            warn!("Poll cancelled by dropped reference.");
        }
    }

    fn nobingo_phase_change(&mut self) {
        if !self.run_bingo_checks() && self.phase != MatchPhase::Overtime {
            self.set_phase(MatchPhase::Running);
        }
    }

    fn endgame_phase_change(&mut self) {
        if self.phase == MatchPhase::Overtime {
            return;
        }

        if self.try_do_bingo_checks() {
            return;
        }

        if self.do_cell_winner_checks() {
            return;
        }

        if self.config.overtime {
            self.set_phase(MatchPhase::Overtime);
        } else {
            self.channel.broadcast(&GameEvent::AnnounceDraw);
            self.set_game_ended(true);
        }
    }
}

impl Default for MatchOptions {
    fn default() -> Self {
        Self {
            start_countdown: CONFIG.game.start_countdown,
        }
    }
}

#[derive(Serialize, Clone, Debug)]
pub struct BingoLine {
    pub direction: Direction,
    pub index: u32,
    pub team: TeamIdentifier,
}

#[derive(Serialize_repr, Clone, Copy, Debug)]
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
        .map(|c| c.team_id);
    iter.fold(first, |acc, x| {
        acc.and_then(|y| {
            if x.leading_claim().as_ref().map(|c| c.team_id) == Some(y) {
                Some(y)
            } else {
                None
            }
        })
    })
}
