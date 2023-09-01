use std::{str::FromStr, sync::Arc};

use once_cell::sync::Lazy;

use crate::{config::CONFIG, orm::composed::profile::PlayerProfile, server};

pub static TEAMS: Lazy<Vec<(String, Color)>> = Lazy::new(|| {
    CONFIG
        .game
        .teams
        .iter()
        .map(|(s, col)| (s.clone(), Color::from_str(col).expect("valid colors")))
        .collect()
});

use super::{
    directory::Owned,
    models::{player::PlayerRef, team::TeamIdentifier},
    room::GameRoom,
    util::Color,
};

pub fn setup_room(room_arc: &Owned<GameRoom>) {
    let mut room = room_arc.lock();

    room.create_team_from_preset(&TEAMS)
        .expect("creating initial 1st team");
    room.create_team_from_preset(&TEAMS)
        .expect("creating initial 2nd team");

    server::mapload::load_maps(
        Arc::downgrade(&room_arc),
        room.matchconfig(),
        room.get_load_marker(),
    );
}

pub struct PlayerData {
    pub uid: i32,
    pub profile: PlayerProfile,
    pub team: TeamIdentifier,
    pub operator: bool,
    pub disconnected: bool,
}

impl From<&PlayerData> for PlayerRef {
    fn from(value: &PlayerData) -> Self {
        Self {
            uid: value.uid,
            team: value.team,
        }
    }
}
