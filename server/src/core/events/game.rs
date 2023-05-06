use serde::Serialize;

use crate::core::livegame::{BingoLine, MapClaim};

#[derive(Serialize)]
#[serde(tag = "event")]
pub enum GameEvent {
    CellClaim {
        cell_id: usize,
        claim: MapClaim,
    },
    AnnounceBingo {
        #[serde(flatten)]
        line: BingoLine,
    },
}
