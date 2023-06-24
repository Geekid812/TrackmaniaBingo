use std::sync::Arc;

use crate::{
    config::CONFIG,
    orm::composed::profile::PlayerProfile,
    server::{
        self,
        context::{GameContext, RoomContext},
    },
};

use super::{
    directory::{self, Owned, Shared},
    models::{player::PlayerRef, team::TeamIdentifier},
    room::GameRoom,
    util::color::RgbColor,
};

pub fn setup_room(room_arc: &Owned<GameRoom>) {
    let mut room = room_arc.lock();
    let teams = CONFIG
        .game
        .teams
        .iter()
        .map(|(s, col)| (s.clone(), RgbColor::from_hex(col).expect("valid colors")))
        .collect(); // TODO: clean up, don't reinitialize every function call
    room.create_team(&teams).expect("creating initial 1st team");
    room.create_team(&teams).expect("creating initial 2nd team");

    server::mapcache::load_maps(
        Arc::downgrade(&room_arc),
        room.matchconfig().clone(),
        room.get_load_marker(),
    );

    if room.config().public {
        directory::send_room_visibility(&room, true);
    }
}

#[derive(Debug, Clone)]
pub struct PlayerData {
    pub profile: PlayerProfile,
    pub team: TeamIdentifier,
    pub operator: bool,
    pub disconnected: bool,
    pub room_ctx: Shared<Option<RoomContext>>,
    pub game_ctx: Shared<Option<GameContext>>,
}

impl From<&PlayerData> for PlayerRef {
    fn from(value: &PlayerData) -> Self {
        Self {
            uid: value.profile.player.uid,
            team: value.team,
        }
    }
}
