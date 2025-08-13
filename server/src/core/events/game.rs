use chrono::Duration;
use serde::Serialize;
use serde_with::DurationMilliSeconds;

use crate::{
    core::{
        livegame::BingoLine,
        models::{
            livegame::{MapClaim, MatchPhase, MatchState},
            map::GameMap,
            team::{BaseTeam, TeamIdentifier},
        },
    },
    datatypes::{ChatMessage, PlayerProfile, PlayerRef, Poll, Powerup},
};

#[serde_with::serde_as]
#[derive(Serialize, Clone, Debug)]
#[serde(tag = "event")]
pub enum GameEvent {
    MatchStart {
        uid: String,
        #[serde_as(as = "DurationMilliSeconds<i64>")]
        start_ms: Duration,
        can_reroll: bool,
        maps: Vec<GameMap>,
    },
    RunSubmitted {
        cell_id: usize,
        claim: MapClaim,
        position: usize,
    },
    AnnounceBingo {
        lines: Vec<BingoLine>,
    },
    AnnounceWinByCellCount {
        team: TeamIdentifier,
    },
    AnnounceDraw,
    PhaseChange {
        phase: MatchPhase,
    },
    MatchSync(MatchState),
    MatchTeamCreated {
        #[serde(flatten)]
        base: BaseTeam,
    },
    MatchPlayerJoin {
        profile: PlayerProfile,
        team: TeamIdentifier,
    },
    PlayerDisconnect {
        uid: i32,
    },
    RerollVoteCast {
        player_id: i32,
        cell_id: usize,
        added: bool,
        count: usize,
        required: usize,
    },
    MapRerolled {
        cell_id: usize,
        map: GameMap,
        can_reroll: bool,
    },
    ChatMessage(ChatMessage),
    PollStart {
        #[serde(flatten)]
        poll: Poll,
        votes: Vec<i32>,
    },
    PollVotesUpdate {
        id: u32,
        votes: Vec<i32>,
    },
    PollResult {
        id: u32,
        selected: Option<u32>,
    },
    PowerupSpawn {
        cell_id: usize,
        is_special: bool,
    },
    ItemSlotEquip {
        uid: u32,
        powerup: Powerup,
    },
    PowerupActivated {
        powerup: Powerup,
        player: PlayerRef,
        board_index: usize,
        forwards: bool,
    },
}
