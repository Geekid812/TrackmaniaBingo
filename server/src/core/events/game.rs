use chrono::{Duration};
use serde::Serialize;
use serde_with::DurationMilliSeconds;

use crate::{
    core::livegame::{BingoLine, MapClaim},
    orm::mapcache::record::MapRecord,
};

#[serde_with::serde_as]
#[derive(Serialize)]
#[serde(tag = "event")]
pub enum GameEvent {
    MatchStart {
        #[serde_as(as = "DurationMilliSeconds<i64>")]
        start_ms: Duration,
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
