use serde::{Deserialize, Serialize};

use crate::orm::mapcache::record::MapRecord;

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct GameMap {
    #[serde(flatten)]
    pub track: MapRecord, // TODO: maybe use this struct as in intermediary to allow other sources (with ::from())
}

impl From<MapRecord> for GameMap {
    fn from(value: MapRecord) -> Self {
        Self { track: value }
    }
}
