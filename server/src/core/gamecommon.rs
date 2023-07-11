use std::sync::Arc;

use once_cell::sync::Lazy;

use crate::{
    config::CONFIG,
    orm::composed::profile::PlayerProfile,
    server::{
        self,
        context::{GameContext, RoomContext},
    },
};

pub static TEAMS: Lazy<Vec<(String, RgbColor)>> = Lazy::new(|| {
    CONFIG
        .game
        .teams
        .iter()
        .map(|(s, col)| (s.clone(), RgbColor::from_hex(col).expect("valid colors")))
        .collect()
});

use super::{
    directory::{Owned, Shared},
    models::{player::PlayerRef, team::TeamIdentifier},
    room::GameRoom,
    util::color::RgbColor,
};

pub fn setup_room(room_arc: &Owned<GameRoom>) {
    let mut room = room_arc.lock();

    room.create_team(&TEAMS).expect("creating initial 1st team");
    room.create_team(&TEAMS).expect("creating initial 2nd team");

    server::mapload::load_maps(
        Arc::downgrade(&room_arc),
        room.matchconfig().clone(),
        room.get_load_marker(),
    );
}

pub struct PlayerData {
    pub uid: i32,
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
            uid: value.uid,
            team: value.team,
        }
    }
}
