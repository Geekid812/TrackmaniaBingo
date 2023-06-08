use serde::Serialize;

use crate::orm::mapcache::record::MapRecord;

#[derive(Serialize, Clone, Debug)]
pub struct GameMap {
    pub record: MapRecord,
}

impl From<MapRecord> for GameMap {
    fn from(value: MapRecord) -> Self {
        Self { record: value }
    }
}
