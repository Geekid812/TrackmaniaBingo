use serde::Serialize;

use crate::core::{
    livegame::MatchConfiguration,
    room::{RoomConfiguration, RoomStatus},
};

#[derive(Serialize)]
#[serde(tag = "event")]
pub enum RoomEvent {
    PlayerUpdate(RoomStatus),
    ConfigUpdate(RoomConfiguration),
    MatchConfigUpdate(MatchConfiguration),
    CloseRoom { message: String },
}
