use anyhow::anyhow;
use rand::{distributions::Standard, seq::IteratorRandom, thread_rng, Rng};
use std::{
    collections::HashMap,
    sync::{Arc, Weak},
};

use crate::{
    config,
    core::models::{
        livegame::{MatchEndInfo, MvpData, TileItemState},
        team::NetworkGameTeam,
    },
    datatypes::{CampaignMap, Gamemode, MatchConfiguration, PlayerRef, Poll, PollChoice, Powerup},
    server::{
        context::ClientContext,
        tasks::{execute_delayed_task, execute_repeating_task},
    },
    store::{
        self,
        matches::{Match, MatchOutcome, MatchResult},
    },
    transport::Channel,
};
use chrono::{DateTime, Duration, TimeDelta, Utc};
use parking_lot::Mutex;
use serde::Serialize;
use serde_repr::Serialize_repr;
use tracing::{error, warn};

use super::{
    directory::{Owned, Shared, MATCHES},
    events::game::GameEvent,
    gamecommon::PlayerId,
    models::{
        livegame::{GameCell, MapClaim, MatchPhase, MatchState},
        map::GameMap,
        player::IngamePlayer,
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
    channel: Channel,
    polls: HashMap<u32, Owned<PollData>>,
    last_claim: Option<MapClaim>,
    idents: u32,
}

struct MatchOptions {
    start_countdown: Duration,
}

struct PollData {
    pub poll: Poll,
    pub votes: Vec<Vec<PlayerId>>,
    pub callback: PollResultCallback,
    pub held_tiles: Vec<GameCell>,
}

pub enum PollResultCallback {
    None,
    Reroll(usize),
    GoldenDice(usize),
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
                .enumerate()
                .map(|(cell_id, map)| GameCell {
                    cell_id,
                    map,
                    claims: Vec::new(),
                    state: TileItemState::Empty,
                    claimant: None,
                    state_player: None,
                    state_deadline: DateTime::default(),
                    state_ident: None,
                })
                .collect(),
            started: None,
            phase: MatchPhase::Starting,
            channel: Channel::new(),
            polls: HashMap::new(),
            last_claim: None,
            idents: 0,
        };
        let arc = Arc::new(Mutex::new(_self));
        arc.lock().ptr = Arc::downgrade(&arc);
        arc
    }

    pub fn set_parent_room(&mut self, room: Shared<GameRoom>) {
        self.room = room;
    }

    pub fn set_channel(&mut self, channel: Channel) {
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
        self.setup_timers();

        if self.config.mode == Gamemode::Frenzy {
            self.setup_powerups();
        }

        self.broadcast_start();
    }

    fn setup_timers(&mut self) {
        let max_duration =
            Duration::minutes(config::get_integer("behaviour.max_match_duration").unwrap_or(0));
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
                |game| game.endmain_phase_change(),
                (countdown_duration + nobingo_duration + main_phase_duration)
                    .to_std()
                    .unwrap(),
            );
        }
        if !max_duration.is_zero() {
            execute_delayed_task(
                self.ptr.clone(),
                |game| game.draw_end_game(),
                (countdown_duration + max_duration).to_std().unwrap(),
            );
        }

        execute_delayed_task(
            self.ptr.clone(),
            move |game| game.set_phase(first_phase),
            countdown_duration.to_std().unwrap(),
        );
    }

    fn setup_powerups(&mut self) {
        let tick_duration = std::time::Duration::from_millis(60)
            / (config::get_integer("behaviour.powerup_tick_rate").unwrap_or(1) as f32
                * (self.config.items_tick_multiplier as f32 / 1000.)) as u32;

        if !tick_duration.is_zero() {
            execute_repeating_task(
                self.ptr.clone(),
                move |game| game.tick_powerups_spawn(),
                tick_duration,
            );
        } else {
            warn!("tick duration is zero, powerups will not be generated.");
        }
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

    pub fn channel(&mut self) -> &mut Channel {
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
            self.teams
                .get_mut(team)
                .unwrap()
                .channel
                .subscribe(ctx.profile.uid, ctx.writer.clone());
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

        team.members.push(IngamePlayer {
            profile: ctx.profile.clone(),
            operator: false,
            disconnected: false,
            holding_powerup: Powerup::Empty,
            item_ident: None,
            writer: ctx.writer.clone(),
        });
        team.channel.subscribe(ctx.profile.uid, ctx.writer.clone());
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
            teams: self
                .teams
                .get_teams()
                .iter()
                .map(NetworkGameTeam::from)
                .collect(),
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
        let running_player = claim.player.clone();

        // Bubble up in the ranking until we find a time that was not beaten
        let mut i = ranking.len();
        while i > 0 {
            let current = &ranking[i - 1];
            if current.player == running_player {
                ranking.remove(i - 1);
            } else if claim.time >= current.time {
                break;
            }
            i -= 1;
        }
        ranking.insert(i, claim.clone());
        self.broadcast_submitted_run(id, claim.clone(), i + 1);

        if self.try_do_bingo_checks() {
            return;
        }
        if self.phase == MatchPhase::Overtime && self.do_cell_winner_checks() {
            return;
        }

        let is_new_record = i == 0;
        if is_new_record {
            self.cells[id].claimant = None;
            self.last_claim = Some(claim);

            if self.cells[id].state == TileItemState::HasPowerup {
                self.cells[id].state = TileItemState::Empty;
                self.give_new_powerup(running_player.clone());
            }

            if self.cells[id].state == TileItemState::Jail
                && self.cells[id].state_player.as_ref().is_some_and(|p| {
                    self.get_player_team(p.uid as i32)
                        == self.get_player_team(running_player.uid as i32)
                })
            {
                self.jail_resolve(id, None);
            }
        }
    }

    fn announce_bingo_and_game_end(&mut self, lines: Vec<BingoLine>) {
        for line in &lines {
            let winning_team = self.get_team_mut(line.team).expect("winning team exists");
            winning_team.winner = true;
        }

        let end_state = self.get_end_state();
        self.channel.broadcast(&GameEvent::AnnounceBingo {
            lines: lines.clone(),
            end_state: end_state.clone(),
        });
        self.set_game_ended(false, end_state);
    }

    fn get_end_state(&self) -> MatchEndInfo {
        MatchEndInfo {
            mvp: self.get_mvp(),
        }
    }

    fn get_mvp(&self) -> Option<MvpData> {
        let mut claimed_maps_count = HashMap::new();

        self.cells
            .iter()
            .filter(|c| !(c.claimant.is_some() || c.state == TileItemState::Rainbow))
            .for_each(|c| {
                if let Some(claim) = c.leading_claim() {
                    if self
                        .teams
                        .get(claim.team_id)
                        .is_some_and(|t| t.winner && t.members.len() > 1)
                    {
                        *claimed_maps_count.entry(claim.player.clone()).or_insert(0) += 1;
                    }
                }
            });

        let last_claim_player_score = self.last_claim.as_ref().map(|c| {
            claimed_maps_count
                .get(&c.player)
                .map(Clone::clone)
                .unwrap_or(0)
        });
        let mut mvp = claimed_maps_count.into_iter().max_by_key(|(_k, v)| *v);

        // give priority to the last scorer if they are equal to current MVP
        if mvp.as_ref().is_some_and(|(_, mvp_score)| {
            last_claim_player_score.is_some_and(|score| score == *mvp_score)
        }) {
            mvp = Some((
                self.last_claim.as_ref().unwrap().player.clone(),
                last_claim_player_score.unwrap(),
            ));
        }

        // don't select mvp if they didn't have a positive score
        // this should never be reached with the current scoring system
        if mvp.as_ref().is_some_and(|(_, score)| *score < 1) {
            return None;
        }

        mvp.map(|(player, score)| MvpData { player, score })
    }

    fn set_game_ended(&mut self, draw: bool, end_state: MatchEndInfo) {
        if let Some(room) = self.room.upgrade() {
            room.lock().reset_match();
        }

        if self.should_match_be_saved() {
            self.save_match_end(draw, end_state.mvp.map(|mvp| mvp.player));
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

    fn save_match_end(&mut self, draw: bool, mvp: Option<PlayerRef>) {
        let match_model = Match {
            uid: self.uid.clone(),
            started_at: self.started.unwrap_or_default(),
            ended_at: Utc::now(),
            mvp_player_uid: mvp.map(|player| player.uid as i32),
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
        self.start_poll(
            poll,
            initial_votes,
            PollResultCallback::Reroll(cell_id),
            Vec::new(),
        );

        Ok(())
    }

    fn reroll_map(&mut self, cell_id: usize) -> Result<(), anyhow::Error> {
        if !self.can_reroll() {
            return Err(anyhow!("tried to reroll, but rerolls are disallowed"));
        }
        if self.cells[cell_id].leading_claim().is_some() || self.cells[cell_id].claimant.is_some() {
            return Err(anyhow!("map is already claimed, cannot reroll it"));
        }

        self.cells.swap_remove(cell_id);
        self.cells[cell_id].cell_id = cell_id;
        self.channel.broadcast(&GameEvent::MapRerolled {
            cell_id,
            map: self.cells[cell_id].map.clone(),
            can_reroll: self.can_reroll(),
        });
        Ok(())
    }

    fn replace_map(&mut self, cell_id: usize, map: GameMap) {
        self.cells[cell_id].map = map;
        self.cells[cell_id].claims.clear();
        self.channel.broadcast(&GameEvent::MapRerolled {
            cell_id,
            map: self.cells[cell_id].map.clone(),
            can_reroll: self.can_reroll(),
        });
    }

    pub fn get_player_mut(&mut self, uid: i32) -> Option<&mut IngamePlayer> {
        let mut players = self
            .teams
            .get_teams_mut()
            .iter_mut()
            .map(|t| &mut t.members)
            .flatten();
        players.find(|p| p.profile.uid == uid)
    }

    pub fn activate_powerup(
        &mut self,
        uid: i32,
        powerup: Powerup,
        board_index: usize,
        forwards: bool,
        choice: i32,
        player_id: i32,
        duration: i64
    ) -> Result<(), String> {
        let Some(player) = self.get_player_mut(uid) else {
            return Err(format!("player with uid '{}' not found", uid));
        };

        if !config::get_boolean("behaviour.skip_checks").unwrap_or(false) {
            if player.holding_powerup != powerup {
                return Err(format!(
                    "not holding powerup {:?}, your held powerup is {:?}",
                    powerup, player.holding_powerup
                ));
            }
        }

        let player_ref = player.as_player_ref();
        let target = if powerup == Powerup::Jail {
            self.get_player_mut(player_id).map(|p| p.as_player_ref())
        } else {
            None
        };

        // Preconditions
        if powerup == Powerup::RainbowTile {
            let old_state = self.cells[board_index].state;
            let prev_bingos_count = self.check_for_bingos().len();
            self.cells[board_index].state = TileItemState::Rainbow;

            let creates_bingo = self.check_for_bingos().len() != prev_bingos_count;
            self.cells[board_index].state = old_state;

            if creates_bingo {
                return Err(
                    "placing this here creates a bingo line, this is not allowed!".to_string(),
                );
            }
        }

        // Powerup activation
        self.give_powerup(player_ref.clone(), Powerup::Empty);
        match powerup {
            Powerup::RowShift | Powerup::ColumnShift => {
                self.powerup_effect_board_shift(powerup == Powerup::RowShift, board_index, forwards)
            }
            Powerup::RainbowTile => self.powerup_effect_rainbow_tile(board_index),
            Powerup::Rally => self.powerup_effect_rally(board_index, duration),
            Powerup::Jail if target.is_some() => {
                self.powerup_effect_jail(board_index, target.clone().unwrap(), duration)
            }
            Powerup::GoldenDice => self.powerup_effect_golden_dice(board_index, choice)?,
            _ => {
                return Err("this powerup can't be activated".to_string());
            }
        };

        self.channel.broadcast(&GameEvent::PowerupActivated {
            powerup,
            player: player_ref,
            board_index,
            forwards,
            target,
            duration,
        });
        self.try_do_bingo_checks();
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

            let end_state = self.get_end_state();
            self.channel.broadcast(&GameEvent::AnnounceWinByCellCount {
                team: winning_team,
                end_state: end_state.clone(),
            });
            self.set_game_ended(false, end_state);
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
                    cell.claimant
                        .is_some_and(|claimant| claimant == team.base.id)
                        || (cell.claimant.is_none()
                            && cell
                                .leading_claim()
                                .is_some_and(|claim| claim.team_id == team.base.id))
                        || cell.state == TileItemState::Rainbow
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
        held_tiles: Vec<GameCell>,
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
            held_tiles,
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

    pub fn get_dice_choices(&self) -> Vec<GameMap> {
        self.cells
            .iter()
            .skip(self.cell_count())
            .take(3)
            .map(|cell| cell.map.clone())
            .collect()
    }

    fn poll_end(&mut self, poll_ref: Shared<PollData>) {
        if let Some(lock) = poll_ref.upgrade() {
            let mut poll = lock.lock();
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
                PollResultCallback::GoldenDice(cell_id) => {
                    self.replace_map(cell_id, poll.held_tiles.remove(selected_choice).map);
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

    fn endmain_phase_change(&mut self) {
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
            self.draw_end_game();
        }
    }

    fn draw_end_game(&mut self) {
        let end_state = self.get_end_state();

        self.channel.broadcast(&GameEvent::AnnounceDraw {
            end_state: end_state.clone(),
        });
        self.set_game_ended(true, end_state);
    }

    fn tick_powerups_spawn(&mut self) {
        let mut rng = thread_rng();
        let num_cells = self.cell_count();
        let powerup_spawn_threshold = config::get_float("behaviour.powerup_spawn").unwrap_or(0.);
        let powerup_spawn_sample = rng.sample::<f64, Standard>(Standard);
        let inactivity_threshold =
            Duration::seconds(config::get_integer("behaviour.claim_inactivity_secs").unwrap_or(0));
        let now = Utc::now();

        if powerup_spawn_sample < powerup_spawn_threshold {
            // a powerup will spawn, choose a tile
            let candidates = self.cells.iter_mut().take(num_cells).filter(|tile| {
                tile.state == TileItemState::Empty
                    && !tile
                        .leading_claim()
                        .is_some_and(|claim| now - claim.timestamp < inactivity_threshold)
            });
            if let Some(chosen_tile) = candidates.choose(&mut rng) {
                chosen_tile.state = TileItemState::HasPowerup;
                self.channel.broadcast(&GameEvent::PowerupSpawn {
                    cell_id: chosen_tile.cell_id,
                    is_special: false,
                });
            }
        }
    }

    fn give_new_powerup(&mut self, player: PlayerRef) {
        if let Some(powerup) = self.draft_powerup() {
            self.give_powerup(player, powerup);
        }
    }

    fn give_powerup(&mut self, player_ref: PlayerRef, powerup: Powerup) {
        let item_ident = self.new_ident();
        if let Some(player) = self.get_player_mut(player_ref.uid as i32) {
            player.holding_powerup = powerup;
            player.item_ident = Some(item_ident);

            if powerup != Powerup::Empty && self.config.items_expire != 0 {
                let pref = player_ref.clone();
                execute_delayed_task(
                    self.ptr.clone(),
                    move |_self| _self.item_expire(pref, item_ident),
                    Duration::seconds(self.config.items_expire.into())
                        .to_std()
                        .unwrap(),
                );
            }
        }

        self.channel.broadcast(&GameEvent::ItemSlotEquip {
            uid: player_ref.uid,
            powerup,
        });
    }

    fn draft_powerup(&mut self) -> Option<Powerup> {
        let item_settings = &self.config().items;
        let mut rng = thread_rng();
        let drafting_probabilities = vec![
            (Powerup::RowShift, item_settings.row_shift),
            (Powerup::ColumnShift, item_settings.column_shift),
            (Powerup::Rally, item_settings.rally),
            (Powerup::Jail, item_settings.jail),
            (Powerup::RainbowTile, item_settings.rainbow),
            (Powerup::GoldenDice, item_settings.golden_dice),
        ];

        let mut drafting_pool = vec![];
        for (powerup, occurences) in drafting_probabilities {
            drafting_pool.extend_from_slice(&[powerup].repeat(occurences as usize));
        }
        drafting_pool.into_iter().choose(&mut rng)
    }

    fn fix_cell_ids(&mut self) {
        self.cells
            .iter_mut()
            .enumerate()
            .for_each(|(i, tile)| tile.cell_id = i);
    }

    fn powerup_effect_board_shift(&mut self, is_row: bool, row_col_index: usize, forwards: bool) {
        let grid_size = self.config().grid_size as usize;
        let mut replace_maps = vec![];

        for i in 0..grid_size {
            let tile_index = if is_row {
                grid_size * row_col_index
            } else {
                grid_size * i + row_col_index - i
            };
            replace_maps.push(self.cells.remove(tile_index));
        }

        if forwards {
            let last = replace_maps.pop().unwrap();
            replace_maps.insert(0, last);
        } else {
            let first = replace_maps.remove(0);
            replace_maps.push(first);
        }

        for i in 0..grid_size {
            let tile_index = if is_row {
                grid_size * row_col_index + i
            } else {
                grid_size * i + row_col_index
            };
            self.cells.insert(tile_index, replace_maps.remove(0));
        }
        self.fix_cell_ids();
    }

    fn powerup_effect_rainbow_tile(&mut self, board_index: usize) {
        self.cells[board_index].state = TileItemState::Rainbow;
    }

    fn powerup_effect_rally(&mut self, board_index: usize, rally_length: i64) {
        let rally_duration = Duration::seconds(rally_length);
        let state_ident = self.new_ident();
        self.cells[board_index].state = TileItemState::Rally;
        self.cells[board_index].state_ident = Some(state_ident);
        self.cells[board_index].state_deadline = Utc::now() + rally_duration;

        execute_delayed_task(
            self.ptr.clone(),
            move |_self| _self.rally_resolve(board_index, Some(state_ident)),
            rally_duration.to_std().unwrap(),
        );
    }

    fn powerup_effect_jail(&mut self, board_index: usize, target: PlayerRef, jail_length: i64) {
        let jail_duration = Duration::seconds(jail_length);

        let state_ident = self.new_ident();
        self.cells[board_index].state = TileItemState::Jail;
        self.cells[board_index].state_player = Some(target);
        self.cells[board_index].state_ident = Some(state_ident);
        self.cells[board_index].state_deadline = Utc::now() + jail_duration;

        execute_delayed_task(
            self.ptr.clone(),
            move |_self| _self.jail_resolve(board_index, Some(state_ident)),
            jail_duration.to_std().unwrap(),
        );
    }

    fn powerup_effect_golden_dice(
        &mut self,
        board_index: usize,
        choice: i32,
    ) -> Result<(), String> {
        if self.cells.len() < self.cell_count() + 3 {
            return Err(
                "not enough possible maps to activate this powerup, effect was cancelled"
                    .to_string(),
            );
        }
        if choice < 0 || choice >= 3 {
            return Err(format!(
                "invalid choice value ({}), powerup effect was cancelled",
                choice
            ));
        }

        let cell_count = self.cell_count();
        let new_tile = self.cells.remove(cell_count + choice as usize);
        let tile = &mut self.cells[board_index];
        if let Some(winning_team) = tile.claimant.or(tile.leading_claim().map(|c| c.team_id)) {
            tile.claimant = Some(winning_team);
        }

        self.replace_map(board_index, new_tile.map);

        // move the other 2 choices to the back of the cells array, so they can be later reused
        let unused_choices: Vec<GameCell> =
            self.cells.drain(cell_count..(cell_count + 2)).collect();
        self.cells.extend(unused_choices.into_iter());

        Ok(())
    }

    fn jail_resolve(&mut self, cell_id: usize, state_ident: Option<u32>) {
        if state_ident.is_none_or(|st1| {
            self.cells[cell_id]
                .state_ident
                .is_some_and(|st2| st1 == st2)
        }) {
            self.cells[cell_id].state = TileItemState::Empty;
            self.cells[cell_id].state_player = None;
            self.cells[cell_id].state_ident = None;
            self.cells[cell_id].state_deadline = DateTime::default();
            self.channel.broadcast(&GameEvent::JailResolved { cell_id });
        }
    }

    fn rally_resolve(&mut self, cell_id: usize, state_ident: Option<u32>) {
        if state_ident.is_none_or(|st1| {
            self.cells[cell_id]
                .state_ident
                .is_some_and(|st2| st1 == st2)
        }) {
            self.cells[cell_id].state = TileItemState::Empty;
            self.cells[cell_id].state_ident = None;
            self.cells[cell_id].state_deadline = DateTime::default();

            let team = self.cells[cell_id]
                .claimant
                .or(self.cells[cell_id].leading_claim().map(|c| c.team_id));

            if let Some(winning_team) = team {
                let tile_up = cell_id as i32 - self.config.grid_size as i32;
                let tile_left = cell_id as i32 - 1;
                let tile_right = cell_id + 1;
                let tile_down = cell_id + self.config.grid_size as usize;

                if tile_up >= 0 {
                    self.cells[tile_up as usize].claimant = Some(winning_team);
                }
                if tile_left >= 0 {
                    self.cells[tile_left as usize].claimant = Some(winning_team);
                }
                if tile_right < self.cell_count() {
                    self.cells[tile_right].claimant = Some(winning_team);
                }
                if tile_down < self.cell_count() {
                    self.cells[tile_down].claimant = Some(winning_team);
                }
            }

            self.channel
                .broadcast(&GameEvent::RallyResolved { cell_id, team });
            self.try_do_bingo_checks();
        }
    }

    fn item_expire(&mut self, player_ref: PlayerRef, item_ident: u32) {
        if let Some(player) = self.get_player_mut(player_ref.uid as i32) {
            if player.item_ident.is_some_and(|ident| ident == item_ident) {
                self.give_powerup(player_ref, Powerup::Empty);
            }
        }
    }

    fn new_ident(&mut self) -> u32 {
        let ident = self.idents;
        self.idents += 1;
        ident
    }
}

impl Default for MatchOptions {
    fn default() -> Self {
        Self {
            start_countdown: TimeDelta::milliseconds(
                config::get_integer("behaviour.start_countdown").unwrap_or(5000),
            ),
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

fn iter_check_unique_team<'a>(iter: impl Iterator<Item = &'a GameCell>) -> Option<TeamIdentifier> {
    let mut cleaned_iter = iter.filter(|x| x.state != TileItemState::Rainbow);
    let first_opt = cleaned_iter.next();

    let Some(first_tile) = first_opt else {
        // we have a Bingo of rainbow tiles, which is funny
        return None;
    };

    let first = first_tile
        .claimant
        .or(first_tile.leading_claim().as_ref().map(|c| c.team_id));
    cleaned_iter.fold(first, |acc, x| {
        acc.and_then(|y| {
            if x.claimant.or(x.leading_claim().as_ref().map(|c| c.team_id)) == Some(y) {
                Some(y)
            } else {
                None
            }
        })
    })
}
