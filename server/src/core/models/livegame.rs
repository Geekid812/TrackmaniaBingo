#![allow(non_camel_case_types)]
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_repr::{Deserialize_repr, Serialize_repr};
use serde_with::serde_as;
use serde_with::TimestampSeconds;

use crate::core::models::team::NetworkGameTeam;
use crate::datatypes::MatchConfiguration;
use crate::datatypes::Medal;
use crate::datatypes::PlayerRef;

use super::map::GameMap;

use super::team::TeamIdentifier;

#[serde_with::serde_as]
#[derive(Serialize, Clone, Debug)]
pub struct MatchState {
    pub uid: String,
    pub config: MatchConfiguration,
    pub phase: MatchPhase,
    pub teams: Vec<NetworkGameTeam>,
    pub cells: Vec<GameCell>,
    pub can_reroll: bool,
    #[serde_as(as = "TimestampSeconds")]
    pub started: DateTime<Utc>,
}

#[serde_with::serde_as]
#[derive(Serialize, Clone, Debug)]
pub struct GameCell {
    pub cell_id: usize,
    pub map: GameMap,
    pub claims: Vec<MapClaim>,
    pub state: TileItemState,
    pub claimant: Option<TeamIdentifier>,
    pub state_player: Option<PlayerRef>,
    #[serde_as(as = "TimestampSeconds")]
    pub state_deadline: DateTime<Utc>,
    #[serde(skip)]
    pub state_ident: Option<u32>,
}

impl GameCell {
    pub fn leading_claim(&self) -> Option<&MapClaim> {
        self.claims.iter().next()
    }
}

#[serde_with::serde_as]
#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct MapClaim {
    pub player: PlayerRef,
    pub team_id: TeamIdentifier,
    pub time: u64,
    pub medal: Medal,
    pub splits: Vec<u64>,
    #[serde_as(as = "TimestampSeconds")]
    pub timestamp: DateTime<Utc>,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct MatchEndInfo {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub mvp: Option<MvpData>,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct MvpData {
    pub player: PlayerRef,
    pub score: i32,
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
