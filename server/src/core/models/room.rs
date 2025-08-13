use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_with::TimestampSeconds;

use crate::{
    core::room,
    datatypes::{MatchConfiguration, RoomConfiguration},
};

use super::{player::Player, team::BaseTeam};

#[derive(Serialize, Clone, Debug)]
pub struct RoomState {
    pub config: RoomConfiguration,
    pub matchconfig: MatchConfiguration,
    pub join_code: String,
    pub teams: Vec<RoomTeam>,
}

#[serde_with::serde_as]
#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct NetworkRoom {
    pub name: String,
    pub join_code: String,
    pub host_name: Option<String>,
    pub config: RoomConfiguration,
    pub match_config: MatchConfiguration,
    pub player_count: usize,
    #[serde_as(as = "TimestampSeconds")]
    pub created: DateTime<Utc>,
    #[serde_as(as = "TimestampSeconds")]
    pub started: DateTime<Utc>,
}

impl From<&room::GameRoom> for NetworkRoom {
    fn from(value: &room::GameRoom) -> Self {
        Self {
            name: value.name().to_owned(),
            join_code: value.join_code().to_owned(),
            host_name: value.host_name(),
            config: value.config().to_owned(),
            match_config: value.matchconfig().to_owned(),
            player_count: value.players().len(),
            created: value.created().to_owned(),
            started: value.start_date().unwrap_or_default(),
        }
    }
}

#[derive(Serialize, Clone, Debug)]
pub struct RoomTeam {
    #[serde(flatten)]
    pub base: BaseTeam,
    pub members: Vec<Player>,
}
