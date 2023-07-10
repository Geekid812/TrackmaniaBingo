use serde::{Deserialize, Serialize};
use serde_repr::{Deserialize_repr, Serialize_repr};

use super::player::PlayerRef;

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct MatchConfiguration {
    pub grid_size: u8,
    pub selection: MapMode,
    pub medal: Medal,
    pub time_limit: u32,
    pub no_bingo_mins: u32,
    pub overtime: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub mappack_id: Option<u32>,
}

#[derive(Serialize, Clone, Debug)]
pub struct MapClaim {
    pub player: PlayerRef,
    pub time: u64,
    pub medal: Medal,
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

#[derive(Clone, Copy, Debug, Serialize_repr, Deserialize_repr, PartialEq, Eq)]
#[repr(u8)]
pub enum MatchPhase {
    Starting,
    NoBingo,
    Running,
    Overtime,
    Ended,
}
