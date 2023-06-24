use serde::Serialize;

use crate::core::models::room::NetworkRoom;

#[derive(Serialize)]
#[serde(tag = "event")]
pub enum RoomlistEvent {
    PublicRooms { rooms: Vec<NetworkRoom> },
    RoomUnlisted { join_code: String },
    RoomListed { room: NetworkRoom },
}
