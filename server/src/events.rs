use serde::Serialize;

use crate::{
    gamedata::{BingoLine, MapClaim},
    gamemap::GameMap,
    gameroom::{RoomConfiguration, RoomStatus},
};

#[derive(Serialize)]
#[serde(tag = "event")]
pub enum ServerEvent {
    RoomUpdate(RoomStatus),
    RoomConfigUpdate(RoomConfiguration),
    MapsLoadResult {
        error: Option<String>,
    },
    GameStart {
        maps: Vec<GameMap>,
    },
    CellClaim {
        cell_id: usize,
        claim: MapClaim,
    },
    AnnounceBingo {
        #[serde(flatten)]
        line: BingoLine,
    },
    CloseRoom {
        message: String,
    },
}
