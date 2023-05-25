use serde::Serialize;

use crate::core::{
    livegame::MatchConfiguration,
    room::{PlayerUpdates, RoomConfiguration},
};

#[derive(Serialize)]
#[serde(tag = "event")]
pub enum RoomEvent {
    PlayerUpdate(PlayerUpdates),
    ConfigUpdate(RoomConfiguration),
    MatchConfigUpdate(MatchConfiguration),
    CloseRoom { message: String },
}
