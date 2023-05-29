use serde::{Deserialize, Serialize};
use serde_repr::{Deserialize_repr, Serialize_repr};

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct MatchConfiguration {
    pub grid_size: u8,
    pub selection: MapMode,
    pub medal: Medal,
    pub time_limit: u32,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub mappack_id: Option<u32>,
}

#[derive(Clone, Copy, Debug, Serialize_repr, Deserialize_repr, PartialEq, Eq)]
#[repr(u8)]
pub enum MapMode {
    TOTD,
    RandomTMX,
    Mappack,
}

#[derive(Clone, Copy, Debug, Serialize_repr, Deserialize_repr, PartialEq, Eq)]
#[repr(u8)]
pub enum Medal {
    Author,
    Gold,
    Silver,
    Bronze,
    None,
}
