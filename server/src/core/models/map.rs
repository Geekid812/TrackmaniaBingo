use serde::Serialize;

use crate::{datatypes::CampaignMap, orm::mapcache::record::MapRecord};

#[derive(Serialize, Clone, Debug)]
#[serde(tag = "type")]
pub enum GameMap {
    TMX(MapRecord),
    Campaign(CampaignMap),
}

impl GameMap {
    pub fn name(&self) -> String {
        match self {
            GameMap::TMX(map) => map.track_name.to_owned(),
            GameMap::Campaign(map) => format!("#{}", map.map.to_string()),
        }
    }
}
