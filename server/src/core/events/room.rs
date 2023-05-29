use serde::Serialize;

use crate::core::{
    livegame::MatchConfiguration, models::room::RoomConfiguration, room::PlayerUpdates,
};

#[derive(Serialize)]
#[serde(tag = "event")]
pub enum RoomEvent {
    PlayerUpdate(PlayerUpdates),
    ConfigUpdate(RoomConfiguration),
    MatchConfigUpdate(MatchConfiguration),
    CloseRoom { message: String },
}
