use serde::{Deserialize, Serialize};

use crate::{datatypes::CampaignMap, orm::mapcache::record::MapRecord};

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(tag = "type")]
pub enum GameMap {
    TMX(MapRecord),
    Campaign(CampaignMap),
}
