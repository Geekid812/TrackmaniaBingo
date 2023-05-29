use serde::Serialize;

use crate::core::models::room::GameRoom;

#[derive(Serialize)]
#[serde(tag = "event")]
pub enum RoomlistEvent {
    PublicRooms { rooms: Vec<GameRoom> },
    RoomUnlisted { join_code: String },
    RoomListed { room: GameRoom },
}
