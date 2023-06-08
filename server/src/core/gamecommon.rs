use std::sync::Arc;

use crate::{config::CONFIG, server};

use super::{directory::Owned, room::GameRoom, util::color::RgbColor};

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
}
