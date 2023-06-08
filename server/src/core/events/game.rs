use serde::Serialize;

use crate::{
    core::livegame::{BingoLine, MapClaim},
    orm::mapcache::record::MapRecord,
};

#[derive(Serialize)]
#[serde(tag = "event")]
pub enum GameEvent {
    MatchStart {
        maps: Vec<MapRecord>,
    },
    CellClaim {
        cell_id: usize,
        claim: MapClaim,
    },
    AnnounceBingo {
        #[serde(flatten)]
        line: BingoLine,
    },
}
