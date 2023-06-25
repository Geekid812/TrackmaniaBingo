use chrono::{DateTime, Utc};
use serde::Serialize;
use serde_with::TimestampSeconds;

use crate::core::models::{
    livegame::MatchConfiguration,
    room::{NetworkRoom, RoomConfiguration},
};

#[serde_with::serde_as]
#[derive(Serialize)]
#[serde(tag = "event")]
pub enum RoomlistEvent {
    PublicRooms {
        rooms: Vec<NetworkRoom>,
    },
    RoomUnlisted {
        join_code: String,
    },
    RoomListed {
        #[serde(flatten)]
        room: NetworkRoom,
    },
    RoomlistPlayerCountUpdate {
        code: String,
        delta: i32,
    },
    RoomlistConfigUpdate {
        code: String,
        config: RoomConfiguration,
        match_config: MatchConfiguration,
    },
    RoomlistInGameStatusUpdate {
        code: String,
        #[serde_as(as = "TimestampSeconds")]
        start_time: DateTime<Utc>,
    },
}
