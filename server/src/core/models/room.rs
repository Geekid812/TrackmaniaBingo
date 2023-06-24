use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_with::TimestampSeconds;

use crate::core::room;

use super::{livegame::MatchConfiguration, player::Player, team::BaseTeam};

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
        }
    }
}

#[derive(Deserialize, Serialize, Clone, Debug)]
pub struct RoomTeam {
    #[serde(flatten)]
    pub base: BaseTeam,
    pub members: Vec<Player>,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct RoomConfiguration {
    pub name: String,
    pub public: bool,
    pub size: u32,
    pub randomize: bool,
}
