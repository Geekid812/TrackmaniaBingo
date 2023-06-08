use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

use crate::core::room;

use super::{livegame::MatchConfiguration, player::Player, team::BaseTeam};

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct GameRoom {
    pub name: String,
    pub join_code: String,
    pub config: RoomConfiguration,
    pub matchconfig: MatchConfiguration,
    pub teams: Vec<RoomTeam>,
    pub created: DateTime<Utc>,
}

impl From<&room::GameRoom> for GameRoom {
    fn from(value: &room::GameRoom) -> Self {
        Self {
            name: value.name().to_owned(),
            join_code: value.join_code().to_owned(),
            config: value.config().to_owned(),
            matchconfig: value.matchconfig().to_owned(),
            teams: value.teams_as_model(),
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
    pub public: bool,
    pub size: u32,
    pub randomize: bool,
}
