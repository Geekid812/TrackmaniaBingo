#![allow(non_camel_case_types)]
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_repr::{Deserialize_repr, Serialize_repr};
use serde_with::serde_as;
use serde_with::TimestampSeconds;

use super::map::GameMap;

use super::{player::PlayerRef, team::BaseTeam};

#[serde_with::serde_as]
#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct MatchState {
    pub config: MatchConfiguration,
    pub phase: MatchPhase,
    pub teams: Vec<BaseTeam>,
    pub cells: Vec<GameCell>,
    #[serde_as(as = "TimestampSeconds")]
    pub started: DateTime<Utc>,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct MatchConfiguration {
    pub grid_size: usize,
    pub selection: MapMode,
    pub medal: Medal,
    pub time_limit: u32,
    pub no_bingo_mins: u32,
    pub overtime: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub mappack_id: Option<u32>,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct GameCell {
    pub map: GameMap,
    pub claims: Vec<MapClaim>,
}

impl GameCell {
    pub fn leading_claim(&self) -> Option<&MapClaim> {
        self.claims.iter().next()
    }
}

#[derive(Serialize, Deserialize, Clone, Debug)]
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
