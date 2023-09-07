use std::{
    collections::HashMap,
    sync::{Arc, Weak},
};

use anyhow::anyhow;
use chrono::{DateTime, Utc};
use parking_lot::Mutex;
use rand::{distributions::Uniform, seq::SliceRandom, Rng};
use serde::{Serialize, Serializer};
use thiserror::Error;
use tracing::debug;

use super::{
    directory::{self, Owned, Shared, PUB_ROOMS_CHANNEL, ROOMS},
    events::{game::GameEvent, room::RoomEvent, roomlist::RoomlistEvent},
    gamecommon::PlayerData,
    livegame::{GameTeam, LiveMatch, MatchConfiguration},
    models::{
        self,
        player::{Player, PlayerRef},
        room::{RoomConfiguration, RoomState, RoomTeam},
        team::{BaseTeam, TeamIdentifier},
    },
    teams::TeamsManager,
    util::Color,
};
use crate::{
    orm::{composed::profile::PlayerProfile, mapcache::record::MapRecord},
    server::{context::ClientContext, mapload},
    transport::Channel,
};

pub struct GameRoom {
    ptr: Shared<Self>,
    join_code: String,
    config: RoomConfiguration,
    matchconfig: MatchConfiguration,
    members: Vec<PlayerData>,
    teams: TeamsManager<BaseTeam>,
    channel: Channel<RoomEvent>,
    created: DateTime<Utc>,
    load_marker: u32,
    loaded_maps: Vec<MapRecord>,
    active_match: Option<Shared<LiveMatch>>,
}

impl GameRoom {
    pub fn create(
        config: RoomConfiguration,
        matchconfig: MatchConfiguration,
        join_code: String,
    ) -> Owned<Self> {
        let _self = Self {
            ptr: Weak::new(),
            join_code,
            config,
            matchconfig,
            members: Vec::new(),
            teams: TeamsManager::new(),
            channel: Channel::new(),
            created: Utc::now(),
            load_marker: 0,
            loaded_maps: Vec::new(),
            active_match: None,
        };
        let arc = Arc::new(Mutex::new(_self));
        arc.lock().ptr = Arc::downgrade(&arc);
        arc
    }

    pub fn name(&self) -> &str {
        &self.config.name
    }

    pub fn join_code(&self) -> &str {
        &self.join_code
    }

    pub fn config(&self) -> &RoomConfiguration {
        &self.config
    }

    pub fn matchconfig(&self) -> &MatchConfiguration {
        &self.matchconfig
    }

    pub fn at_size_capacity(&self) -> bool {
        self.config.size != 0 && (self.members.len() as u32) >= self.config.size
    }

    pub fn channel(&mut self) -> &mut Channel<RoomEvent> {
        &mut self.channel
    }

    pub fn created(&self) -> &DateTime<Utc> {
        &self.created
    }

    pub fn players(&self) -> &Vec<PlayerData> {
        &self.members
    }

    pub fn players_mut(&mut self) -> &mut Vec<PlayerData> {
        &mut self.members
    }

    pub fn active_match(&self) -> &Option<Shared<LiveMatch>> {
        &self.active_match
    }

    pub fn teams(&self) -> &Vec<BaseTeam> {
        &self.teams.get_teams()
    }

    pub fn get_player(&self, uid: i32) -> Option<&PlayerData> {
        self.members.iter().filter(|p| p.uid == uid).next()
    }

    pub fn get_player_mut(&mut self, uid: i32) -> Option<&mut PlayerData> {
        self.members.iter_mut().filter(|p| p.uid == uid).next()
    }

    pub fn get_team(&self, id: TeamIdentifier) -> Option<&BaseTeam> {
        self.teams.get(id)
    }

    pub fn teams_as_model(&self) -> Vec<RoomTeam> {
        self.team_members()
            .into_iter()
            .map(|(tid, players)| RoomTeam {
                base: self
                    .get_team(tid)
                    .expect("teams should be valid")
                    .to_owned(),
                members: players
                    .iter()
                    .map(|id| Player::from(self.get_player(*id).expect("members should be valid")))
                    .collect(),
            })
            .collect()
    }

    fn team_members(&self) -> HashMap<TeamIdentifier, Vec<i32>> {
        let mut map: HashMap<TeamIdentifier, Vec<i32>> = HashMap::new();
        self.members.iter().for_each(|p| {
            map.entry(p.team).or_default().push(p.profile.player.uid);
        });
        self.teams.get_teams().iter().for_each(|t| {
            map.entry(t.id).or_default();
        });

        map
    }

    pub fn host_name(&self) -> Option<String> {
        self.members
            .iter()
            .find(|p| p.operator)
            .map(|p| p.profile.player.username.clone())
    }

    pub fn has_player(&self, uid: i32) -> bool {
        self.members.iter().any(|m| m.profile.player.uid == uid)
    }

    pub fn get_state(&self) -> RoomState {
        RoomState {
            config: self.config.clone(),
            matchconfig: self.matchconfig.clone(),
            join_code: self.join_code.clone(),
            teams: self.teams_as_model(),
        }
    }

    pub fn add_player(
        &mut self,
        ctx: &ClientContext,
        profile: &PlayerProfile,
        operator: bool,
    ) -> TeamIdentifier {
        let team = self
            .get_least_populated_team()
            .expect("0 teams in self.teams")
            .id;
        self.members.push(PlayerData {
            uid: profile.player.uid,
            profile: profile.clone(),
            team,
            operator,
            disconnected: false,
        });
        self.channel
            .subscribe(profile.player.uid, ctx.writer.clone());
        team
    }

    pub fn get_load_marker(&self) -> u32 {
        self.load_marker
    }

    pub fn maps_load_callback(&mut self, maps: Vec<MapRecord>, userdata: u32) {
        if userdata == self.load_marker {
            self.loaded_maps = maps;
        }
    }

    pub fn has_started(&self) -> bool {
        self.active_match
            .as_ref()
            .map(|weak| weak.strong_count() > 0)
            .unwrap_or(false)
    }

    pub fn player_join(
        &mut self,
        ctx: &ClientContext,
        profile: &PlayerProfile,
    ) -> Result<(), JoinRoomError> {
        if self.at_size_capacity() {
            return Err(JoinRoomError::PlayerLimitReached);
        }
        if self.has_started() {
            return Err(JoinRoomError::HasStarted);
        }
        if self.has_player(ctx.profile.player.uid) {
            return Err(JoinRoomError::PlayerAlreadyJoined);
        }

        let team = self.add_player(ctx, profile, false);
        self.channel.broadcast(&RoomEvent::PlayerJoin {
            profile: profile.clone(),
            team,
        });

        if self.config.public {
            PUB_ROOMS_CHANNEL
                .lock()
                .broadcast(&RoomlistEvent::RoomlistPlayerCountUpdate {
                    code: self.join_code.clone(),
                    delta: 1,
                });
        }
        Ok(())
    }

    pub fn player_remove(&mut self, uid: i32) {
        self.members.retain(|m| m.uid != uid);
        self.channel.unsubscribe(uid);
        self.channel.broadcast(&RoomEvent::PlayerLeave { uid: uid });

        if self.config.public {
            PUB_ROOMS_CHANNEL
                .lock()
                .broadcast(&RoomlistEvent::RoomlistPlayerCountUpdate {
                    code: self.join_code.clone(),
                    delta: -1,
                });
        }
    }

    pub fn change_team(&mut self, uid: i32, team: TeamIdentifier) -> bool {
        if !self.teams.exists(team) {
            return false;
        }
        if let Some(data) = self.members.iter_mut().find(|m| m.uid == uid) {
            data.team = team;
            let uid = data.profile.player.uid;
            self.player_update(vec![(uid, team)]);
        }
        true
    }

    pub fn sort_teams(&mut self) {
        let mut unproccessed: Vec<&mut PlayerData> = self.members.iter_mut().collect();
        let mut teams = self.teams.get_teams().iter().cycle();
        let mut rng = rand::thread_rng();
        while unproccessed.len() > 0 {
            let dist = Uniform::new(0, unproccessed.len());
            let selected = unproccessed.remove(rng.sample(dist));
            selected.team = teams.next().unwrap().id;
        }
    }

    pub fn remove_team(&mut self, id: TeamIdentifier) {
        let team = self.teams.remove_team(id);
        if let Some(team) = team {
            let mut updated_players = Vec::new();
            let default = self.teams.get_index(0).unwrap().id;
            self.members.iter_mut().for_each(|p| {
                if p.team == team.id {
                    p.team = default;
                    updated_players.push(p);
                }
            });

            if updated_players.len() > 0 {
                self.channel
                    .broadcast(&RoomEvent::PlayerUpdate(PlayerUpdates {
                        updates: HashMap::from_iter(
                            updated_players
                                .into_iter()
                                .map(|p| (p.profile.player.uid, default)),
                        ),
                    }));
            }
        }
        self.channel.broadcast(&RoomEvent::TeamDeleted { id });
    }

    pub fn create_team_from_preset(&mut self, teams: &Vec<(String, Color)>) -> Option<BaseTeam> {
        let team = self
            .teams
            .create_team_from_preset(teams)
            .map(BaseTeam::clone);
        if let Some(team) = team.clone() {
            self.team_created(team);
        }
        team
    }

    pub fn get_least_populated_team(&self) -> Option<&BaseTeam> {
        self.teams
            .get_teams()
            .iter()
            .min_by_key(|team| self.members.iter().filter(|m| m.team == team.id).count())
    }

    fn team_created(&mut self, team: BaseTeam) {
        self.channel
            .broadcast(&RoomEvent::TeamCreated { base: team })
    }

    fn create_ffa_teams(&mut self) {
        self.teams = TeamsManager::new();
        for i in 0..self.members.len() {
            let team = self.teams.create_random_team().clone();
            self.members[i].team = team.id;
            self.team_created(team);
        }
    }

    pub fn set_config(&mut self, config: RoomConfiguration) {
        self.trigger_new_config(config);
        self.config_update();
    }

    pub fn set_matchconfig(&mut self, config: MatchConfiguration) {
        self.trigger_new_matchconfig(config);
        self.config_update();
    }

    fn trigger_new_config(&mut self, config: RoomConfiguration) {
        if config.public != self.config.public {
            directory::send_room_visibility(self, config.public);
        }
        self.config = config;
    }

    fn trigger_new_matchconfig(&mut self, config: MatchConfiguration) {
        if config.selection != self.matchconfig.selection
            || self.matchconfig.mappack_id != config.mappack_id
            || self.matchconfig.map_tag != config.map_tag
            || self.matchconfig.grid_size < config.grid_size
        {
            // map selection changed, reload maps
            self.loaded_maps = Vec::new();
            mapload::load_maps(self.ptr.clone(), &config, self.get_load_marker());
        }

        self.matchconfig = config;
    }

    pub fn set_configs(&mut self, config: RoomConfiguration, matchconfig: MatchConfiguration) {
        self.trigger_new_config(config);
        self.trigger_new_matchconfig(matchconfig);
        self.config_update();
    }

    pub fn player_update(&mut self, players: Vec<(i32, TeamIdentifier)>) {
        let update = PlayerUpdates {
            updates: HashMap::from_iter(players.into_iter()),
        };
        self.channel.broadcast(&RoomEvent::PlayerUpdate(update));
    }

    pub fn config_update(&mut self) {
        self.channel.broadcast(&RoomEvent::ConfigUpdate {
            config: self.config.clone(),
            match_config: self.matchconfig.clone(),
        });

        if self.config.public {
            PUB_ROOMS_CHANNEL
                .lock()
                .broadcast(&RoomlistEvent::RoomlistConfigUpdate {
                    code: self.join_code.clone(),
                    config: self.config.clone(),
                    match_config: self.matchconfig.clone(),
                });
        }
    }

    pub fn check_close(&mut self) {
        if !self.members.iter().any(|p| p.operator) {
            debug!("No room operator, closing.");
            self.close_room("The host has left the room.".to_owned());
        }
    }

    pub fn close_room(&mut self, message: String) {
        self.channel.broadcast(&RoomEvent::CloseRoom { message });
        ROOMS.remove(self.join_code.clone());

        // self.members.iter_mut().for_each(|p| {
        //    p.room_ctx.upgrade().map(|ctx| *ctx.lock() = None);
        // });

        if self.config.public {
            directory::send_room_visibility(&self, false);
        }
    }

    pub fn broadcast_sync(&mut self) {
        self.channel
            .broadcast(&RoomEvent::RoomSync(self.get_state()));
    }

    fn prepare_start_match(&mut self) {
        if self.config.randomize {
            self.sort_teams();
            self.channel
                .broadcast(&RoomEvent::PlayerUpdate(PlayerUpdates {
                    updates: HashMap::from_iter(self.members.iter().map(|p| (p.uid, p.team))),
                }));
        }

        if self.matchconfig.free_for_all {
            self.create_ffa_teams();
            self.broadcast_sync();
        }

        self.loaded_maps.shuffle(&mut rand::thread_rng());
    }

    pub fn check_start_match(&mut self) -> Result<Owned<LiveMatch>, anyhow::Error> {
        let map_count_minimum = self.matchconfig.grid_size * self.matchconfig.grid_size;
        let count = self.loaded_maps.len();
        if count < map_count_minimum {
            let mut err = anyhow!("Could not load enough maps to start the game: {} maps needed, but only {} could be loaded.", map_count_minimum, count);
            if count == 0 {
                err = anyhow!("Could not load the maps to start the game. Please wait a moment or try changing the map selection settings.");
            }
            return Err(err);
        }
        Ok(self.start_match())
    }

    fn start_match(&mut self) -> Owned<LiveMatch> {
        self.prepare_start_match();
        let start_date = Utc::now();
        let match_arc = LiveMatch::new(
            self.matchconfig.clone(),
            self.loaded_maps.clone(),
            TeamsManager::from_teams(
                self.teams_as_model()
                    .into_iter()
                    .map(GameTeam::from)
                    .collect(),
                self.teams.teams_id(),
            ),
        );
        let mut lock = match_arc.lock();
        lock.set_parent_room(self.ptr.clone());
        lock.set_channel(Channel::<GameEvent>::from(&self.channel));
        lock.setup_match_start(start_date);
        directory::MATCHES.insert(lock.uid().to_owned(), match_arc.clone());
        drop(lock);

        self.active_match = Some(Arc::downgrade(&match_arc));
        self.send_in_game_status_update();
        match_arc
    }

    pub fn get_match(&self) -> Option<Owned<LiveMatch>> {
        self.active_match.as_ref().and_then(|m| m.upgrade())
    }

    pub fn start_date(&self) -> Option<DateTime<Utc>> {
        self.active_match.as_ref().and_then(|weak| {
            weak.upgrade()
                .and_then(|game| game.lock().playstart_date().clone())
        })
    }

    pub fn reset_match(&mut self) {
        if let Some(match_) = self.active_match.as_ref().and_then(|m| m.upgrade()) {
            directory::MATCHES.remove_item(match_);
        }
        self.active_match = None;
        self.send_in_game_status_update();
    }

    fn send_in_game_status_update(&self) {
        if self.config.public {
            let start_time = self.start_date().unwrap_or_default();
            PUB_ROOMS_CHANNEL
                .lock()
                .broadcast(&RoomlistEvent::RoomlistInGameStatusUpdate {
                    code: self.join_code.clone(),
                    start_time,
                })
        }
    }
}

impl Serialize for GameRoom {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        models::room::NetworkRoom::from(self).serialize(serializer)
    }
}

#[derive(Error, Debug)]
pub enum JoinRoomError {
    #[error("The room is already full.")]
    PlayerLimitReached,
    #[error("No room was found with code {0}.")]
    DoesNotExist(String),
    #[error("The game has already started.")]
    HasStarted,
    #[error("You have already joined this room.")]
    PlayerAlreadyJoined,
}

#[derive(Serialize)]
pub struct PlayerUpdates {
    pub updates: HashMap<i32, TeamIdentifier>,
}

#[derive(Serialize, Clone, Debug)]
pub struct NetworkTeam {
    pub info: BaseTeam,
    pub members: Vec<PlayerRef>,
}

#[derive(Serialize, Clone, Debug)]
pub struct NetworkRoom {
    pub name: String,
    pub join_code: String,
    pub hostname: Option<String>,
    pub config: RoomConfiguration,
    pub matchconfig: MatchConfiguration,
    pub player_count: i32,
}
