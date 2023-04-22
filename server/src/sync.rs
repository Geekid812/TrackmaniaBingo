use serde::Serialize;

use crate::{
    gamedata::ActiveGameData,
    gamemap::GameMap,
    gameroom::{GameRoom, RoomConfiguration, RoomStatus},
    rest::auth::PlayerIdentity,
};

#[derive(Serialize)]
pub struct SyncPacket {
    room_name: String,
    join_code: String,
    host: bool,
    config: RoomConfiguration,
    status: RoomStatus,
    maps: Vec<GameMap>,
    #[serde(skip_serializing_if = "Option::is_none")]
    game_data: Option<ActiveGameData>,
}

pub fn build_sync_packet(room: &mut GameRoom, identity: PlayerIdentity) -> Option<SyncPacket> {
    room.get_player(identity).map(|player| SyncPacket {
        room_name: room.name().to_string(),
        join_code: room.join_code().to_string(),
        host: player.operator,
        config: room.config().clone(),
        status: room.status(),
        maps: room.maps().clone(),
        game_data: room.game_data().clone(),
    })
}
