use chrono::Duration;
use serde::Serialize;
use serde_with::DurationMilliSeconds;

use crate::{
    core::{
        livegame::BingoLine,
        models::livegame::{MapClaim, MatchPhase},
    },
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
    RunSubmitted {
        cell_id: usize,
        claim: MapClaim,
        position: usize,
    },
    AnnounceBingo {
        #[serde(flatten)]
        line: BingoLine,
    },
    PhaseChange {
        phase: MatchPhase,
    },
}
