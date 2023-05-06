use std::collections::HashMap;

use chrono::{DateTime, Utc};
use rand::Rng;
use serde::{Deserialize, Serialize};
use thiserror::Error;
use tracing::warn;

use super::{
    events::room::RoomEvent,
    identity::PlayerIdentity,
    livegame::MatchConfiguration,
    team::{BaseTeam, TeamIdentifier},
    util::color::RgbColor,
};
use crate::transport::Channel;

pub struct GameRoom {
    name: String,
    join_code: String,
    config: RoomConfiguration,
    matchconfig: MatchConfiguration,
    members: Vec<PlayerData>,
    teams: Vec<BaseTeam>,
    channel: Channel<RoomEvent>,
    created: DateTime<Utc>,
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
            members: Vec::new(),
            teams: Vec::new(),
            channel: Channel::new(),
            created: Utc::now(),
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
        self.config.size != 0 && (self.members.len() as u32) < self.config.size
    }

    pub fn channel(&mut self) -> &mut Channel<RoomEvent> {
        &mut self.channel
    }

    pub fn created(&self) -> &DateTime<Utc> {
        &self.created
    }

    pub fn players(&self) -> Vec<NetworkPlayer> {
        self.members.iter().map(NetworkPlayer::from).collect()
    }

    pub fn teams(&self) -> Vec<NetworkTeam> {
        let mut map: HashMap<TeamIdentifier, Vec<NetworkPlayer>> = HashMap::new();
        self.members.iter().for_each(|p| {
            map.entry(p.team).or_default().push(NetworkPlayer::from(p));
        });

        self.teams
            .iter()
            .map(|t| NetworkTeam {
                info: t.clone(),
                members: map.remove(&t.id).unwrap_or_default(),
            })
            .collect()
    }

    pub fn status(&self) -> RoomStatus {
        RoomStatus {
            teams: self.teams(),
        }
    }

    pub fn host_name(&self) -> Option<String> {
        self.members
            .iter()
            .find(|p| p.operator)
            .map(|p| p.identity.display_name.clone())
    }

    pub fn get_player(&self, identity: PlayerIdentity) -> Option<&PlayerData> {
        self.members.iter().find(|p| p.identity == identity)
    }

    pub fn get_team(&self, identifier: TeamIdentifier) -> Option<&BaseTeam> {
        self.teams.iter().find(|t| t.id == identifier)
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
        self.teams.push(BaseTeam::new(teams[idx].0.clone(), color));
        self.room_update();
        self.teams.last()
    }

    fn team_exsits(&self, id: TeamIdentifier) -> bool {
        self.teams.iter().any(|t| t.id == id)
    }

    fn team_exsits_with_name(&self, name: &str) -> bool {
        self.teams.iter().any(|t| t.name == name)
    }

    pub fn add_player(&mut self, identity: &PlayerIdentity, operator: bool) {
        let team = self.teams[0].id; // TODO: sort into teams when joining
        self.members.push(PlayerData {
            identity: identity.clone(),
            team,
            operator,
            disconnected: false,
        });
        self.room_update();
    }

    pub fn player_join(&mut self, identity: &PlayerIdentity) -> Result<(), JoinRoomError> {
        if self.at_size_capacity() {
            return Err(JoinRoomError::PlayerLimitReached);
        }
        // TODO: reimplement room started check
        Ok(self.add_player(identity, false))
    }

    pub fn player_remove(&mut self, identity: &PlayerIdentity) {
        for i in 0..self.members.len() {
            if &self.members[i].identity == identity {
                self.members.remove(i);
                break;
            }
        }
        self.room_update();
    }

    pub fn change_team(&mut self, identity: &PlayerIdentity, team: TeamIdentifier) -> bool {
        if !self.team_exsits(team) {
            return false;
        }
        if let Some(data) = self
            .members
            .iter_mut()
            .filter(|m| &m.identity == identity)
            .next()
        {
            data.team = team;
        }
        self.room_update();
        true
    }

    pub fn set_config(&mut self, config: RoomConfiguration) {
        self.config = config;
        self.config_update();
    }

    pub fn set_matchconfig(&mut self, config: MatchConfiguration) {
        self.matchconfig = config;
        self.matchconfig_update();
    }

    pub fn room_update(&mut self) {
        self.channel
            .broadcast(&RoomEvent::PlayerUpdate(self.status()));
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

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct RoomConfiguration {
    pub public: bool,
    pub size: u32,
    pub randomize: bool,
}

#[derive(Serialize)]
pub struct RoomStatus {
    pub teams: Vec<NetworkTeam>,
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

pub struct PlayerData {
    pub identity: PlayerIdentity,
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
            name: value.identity.display_name.clone(),
            team: value.team,
        }
    }
}

#[derive(Serialize, Clone, Debug)]
pub struct NetworkTeam {
    pub info: BaseTeam,
    pub members: Vec<NetworkPlayer>,
}
