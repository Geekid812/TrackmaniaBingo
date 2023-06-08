use std::collections::HashMap;

use chrono::{DateTime, Utc};
use rand::Rng;
use serde::{Serialize, Serializer};
use thiserror::Error;
use tracing::warn;

use super::{
    directory,
    events::room::RoomEvent,
    livegame::MatchConfiguration,
    models::{
        self,
        player::RoomPlayer,
        room::{RoomConfiguration, RoomTeam},
        team::{BaseTeam, TeamIdentifier},
    },
    util::color::RgbColor,
};
use crate::{
    orm::{composed::profile::PlayerProfile, mapcache::record::MapRecord},
    transport::Channel,
};

pub struct GameRoom {
    name: String,
    join_code: String,
    config: RoomConfiguration,
    matchconfig: MatchConfiguration,
    members: HashMap<i32, PlayerData>,
    teams: HashMap<TeamIdentifier, BaseTeam>,
    teams_id: usize,
    channel: Channel<RoomEvent>,
    created: DateTime<Utc>,
    load_marker: u32,
    loaded_maps: Vec<MapRecord>,
}

impl GameRoom {
    pub fn create(
        config: RoomConfiguration,
        matchconfig: MatchConfiguration,
        name: String,
        join_code: String,
    ) -> Self {
        Self {
            name,
            join_code,
            config,
            matchconfig,
            members: HashMap::new(),
            teams: HashMap::new(),
            teams_id: 0,
            channel: Channel::new(),
            created: Utc::now(),
            load_marker: 0,
            loaded_maps: Vec::new(),
        }
    }

    pub fn name(&self) -> &str {
        &self.name
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

    pub fn players(&self) -> Vec<&PlayerData> {
        self.members.values().collect()
    }

    pub fn teams(&self) -> Vec<&BaseTeam> {
        self.teams.values().collect()
    }

    pub fn teams_as_model(&self) -> Vec<RoomTeam> {
        self.team_members()
            .into_iter()
            .map(|(tid, players)| RoomTeam {
                base: self
                    .teams
                    .get(&tid)
                    .expect("teams should be valid")
                    .to_owned(),
                members: players
                    .iter()
                    .map(|id| {
                        RoomPlayer::from(self.members.get(id).expect("members should be valid"))
                    })
                    .collect(),
            })
            .collect()
    }

    fn team_members(&self) -> HashMap<TeamIdentifier, Vec<i32>> {
        let mut map: HashMap<TeamIdentifier, Vec<i32>> = HashMap::new();
        self.members.values().for_each(|p| {
            map.entry(p.team).or_default().push(p.profile.player.uid);
        });

        map
    }

    pub fn host_name(&self) -> Option<String> {
        self.members
            .values()
            .find(|p| p.operator)
            .map(|p| p.profile.player.username.clone())
    }

    pub fn get_player(&self, uid: i32) -> Option<&PlayerData> {
        self.members.get(&uid)
    }

    pub fn get_player_mut(&mut self, uid: i32) -> Option<&mut PlayerData> {
        self.members.get_mut(&uid)
    }

    pub fn get_team(&self, identifier: TeamIdentifier) -> Option<&BaseTeam> {
        self.teams.get(&identifier)
    }

    pub fn create_team(&mut self, teams: &Vec<(String, RgbColor)>) -> Option<&BaseTeam> {
        let team_count = self.teams.len();
        if team_count >= teams.len() {
            warn!("attempted to create more than {} teams", teams.len());
            return None;
        }

        let mut rng = rand::thread_rng();
        let mut idx = rng.gen_range(0..teams.len());
        while self.team_exsits_with_name(&teams[idx].0) {
            idx = rng.gen_range(0..teams.len());
        }

        let color = teams[idx].1;
        let team = BaseTeam::new(self.teams_id, teams[idx].0.clone(), color);
        self.teams_id += 1;
        let team_id = team.id;
        self.teams.insert(team_id, team);
        self.teams.get(&team_id)
    }

    fn team_exsits(&self, id: TeamIdentifier) -> bool {
        self.teams.get(&id).is_some()
    }

    fn team_exsits_with_name(&self, name: &str) -> bool {
        self.teams.values().any(|t| t.name == name)
    }

    pub fn add_player(&mut self, profile: &PlayerProfile, operator: bool) {
        let team = self
            .teams
            .values()
            .next()
            .expect("0 teams in self.teams")
            .id; // TODO: sort into teams when joining
        self.members.insert(
            profile.player.uid,
            PlayerData {
                profile: profile.clone(),
                team,
                operator,
                disconnected: false,
            },
        );
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
        false // TODO
    }

    pub fn player_join(&mut self, profile: &PlayerProfile) -> Result<(), JoinRoomError> {
        if self.at_size_capacity() {
            return Err(JoinRoomError::PlayerLimitReached);
        }
        // TODO: reimplement room started check
        Ok(self.add_player(profile, false))
    }

    pub fn player_remove(&mut self, uid: i32) {
        self.members.remove(&uid);
    }

    pub fn change_team(&mut self, uid: i32, team: TeamIdentifier) -> bool {
        if !self.team_exsits(team) {
            return false;
        }
        if let Some(data) = self.members.get_mut(&uid) {
            data.team = team;
            let uid = data.profile.player.uid;
            self.player_update(vec![(uid, team)]);
        }
        true
    }

    pub fn set_config(&mut self, config: RoomConfiguration) {
        if config.public != self.config.public {
            directory::send_room_visibility(self, config.public);
        }
        self.config = config;
        self.config_update();
    }

    pub fn set_matchconfig(&mut self, config: MatchConfiguration) {
        if config.selection != self.matchconfig.selection {
            // reload maps
        }
        self.matchconfig = config;
        self.matchconfig_update();
    }

    pub fn player_update(&mut self, players: Vec<(i32, TeamIdentifier)>) {
        let update = PlayerUpdates {
            updates: HashMap::from_iter(players.into_iter()),
        };
        self.channel.broadcast(&RoomEvent::PlayerUpdate(update));
    }

    pub fn config_update(&mut self) {
        self.channel
            .broadcast(&RoomEvent::ConfigUpdate(self.config.clone()));
    }

    pub fn matchconfig_update(&mut self) {
        self.channel
            .broadcast(&RoomEvent::MatchConfigUpdate(self.matchconfig.clone()));
    }

    pub fn close_room(&mut self, message: String) {
        self.channel.broadcast(&RoomEvent::CloseRoom { message });
    }
}

impl Serialize for GameRoom {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        models::room::GameRoom::from(self).serialize(serializer)
    }
}

#[derive(Serialize)]
pub struct PlayerUpdates {
    pub updates: HashMap<i32, TeamIdentifier>,
}

#[derive(Error, Debug)]
pub enum JoinRoomError {
    #[error("The room is already full.")]
    PlayerLimitReached,
    #[error("No room was found with code {0}.")]
    DoesNotExist(String),
    #[error("The game has already started.")]
    HasStarted,
}

#[derive(Debug, Clone)]
pub struct PlayerData {
    pub profile: PlayerProfile,
    pub team: TeamIdentifier,
    pub operator: bool,
    pub disconnected: bool,
}

#[derive(Serialize, Clone, Debug)]
pub struct NetworkPlayer {
    pub name: String,
    pub team: TeamIdentifier,
}

impl From<&PlayerData> for NetworkPlayer {
    fn from(value: &PlayerData) -> Self {
        Self {
            name: value.profile.player.username.clone(),
            team: value.team,
        }
    }
}

#[derive(Serialize, Clone, Debug)]
pub struct NetworkTeam {
    pub info: BaseTeam,
    pub members: Vec<NetworkPlayer>,
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
