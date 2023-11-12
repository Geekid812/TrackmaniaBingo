use chrono::Duration;
use serde::Serialize;
use serde_with::DurationMilliSeconds;

use crate::{
    core::{
        livegame::BingoLine,
        models::{
            livegame::{MapClaim, MatchPhase, MatchState},
            team::{BaseTeam, TeamIdentifier},
        },
    },
    datatypes::PlayerRef,
    orm::{composed::profile::PlayerProfile, mapcache::record::MapRecord},
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
        maps: Vec<MapRecord>,
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
        map: MapRecord,
        can_reroll: bool,
    },
    CellPinged {
        // Note: pings are leaked to all game teams,
        // this will be resolved when team channels are implemented
        team: TeamIdentifier,
        cell_id: usize,
        player: PlayerRef,
    },
}
