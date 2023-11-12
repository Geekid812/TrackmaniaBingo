use serde::Serialize;

use crate::{
    core::{
        models::{
            room::RoomState,
            team::{BaseTeam, TeamIdentifier},
        },
        room::PlayerUpdates,
    },
    datatypes::{MatchConfiguration, RoomConfiguration},
    orm::composed::profile::PlayerProfile,
};

#[derive(Serialize, Clone, Debug)]
#[serde(tag = "event")]
pub enum RoomEvent {
    PlayerJoin {
        profile: PlayerProfile,
        team: TeamIdentifier,
    },
    PlayerLeave {
        uid: i32,
    },
    PlayerUpdate(PlayerUpdates),
    ConfigUpdate {
        config: RoomConfiguration,
        match_config: MatchConfiguration,
    },
    CloseRoom {
        message: String,
    },
    TeamCreated {
        #[serde(flatten)]
        base: BaseTeam,
    },
    TeamDeleted {
        id: TeamIdentifier,
    },
    RoomSync(RoomState),
}
