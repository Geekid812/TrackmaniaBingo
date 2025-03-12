use std::sync::Arc;

use crate::{datatypes::PlayerProfile, server, transport::messager::NetMessager};

pub type PlayerId = u32;

use super::{
    directory::Owned,
    models::team::{BaseTeam, TeamIdentifier},
    room::GameRoom,
};

pub fn setup_room(room_arc: &Owned<GameRoom>, teams: &Vec<BaseTeam>) {
    let mut room = room_arc.lock();
    let team_presets = teams.iter().map(|t| (t.name.clone(), t.color)).collect();

    room.create_team_from_preset(&team_presets)
        .expect("creating initial 1st team");
    room.create_team_from_preset(&team_presets)
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
    pub writer: NetMessager,
}
