#![allow(non_camel_case_types)]
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_repr::{Deserialize_repr, Serialize_repr};
use serde_with::serde_as;
use serde_with::TimestampSeconds;

use crate::datatypes::MatchConfiguration;
use crate::datatypes::Medal;
use crate::datatypes::PlayerRef;

use super::map::GameMap;

use super::team::GameTeam;
use super::team::TeamIdentifier;

#[serde_with::serde_as]
#[derive(Serialize, Clone, Debug)]
pub struct MatchState {
    pub uid: String,
    pub config: MatchConfiguration,
    pub phase: MatchPhase,
    pub teams: Vec<GameTeam>,
    pub cells: Vec<GameCell>,
    pub can_reroll: bool,
    #[serde_as(as = "TimestampSeconds")]
    pub started: DateTime<Utc>,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct GameCell {
    pub cell_id: usize,
    pub map: GameMap,
    pub claims: Vec<MapClaim>,
    pub reroll_ids: Vec<i32>,
    pub state: TileItemState,
}

impl GameCell {
    pub fn leading_claim(&self) -> Option<&MapClaim> {
        self.claims.iter().next()
    }
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct MapClaim {
    pub player: PlayerRef,
    pub team_id: TeamIdentifier,
    pub time: u64,
    pub medal: Medal,
    pub splits: Vec<u64>,
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

#[derive(Clone, Copy, Debug, Serialize_repr, Deserialize_repr, PartialEq, Eq)]
#[repr(u8)]
pub enum TileItemState {
    Empty,
    HasPowerup,
    HasSpecialPowerup,
    Rainbow,
    Rally,
    Jail,
}
