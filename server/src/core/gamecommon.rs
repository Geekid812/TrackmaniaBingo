use crate::config::CONFIG;

use super::{room::GameRoom, util::color::RgbColor};

pub fn setup_room(room: &mut GameRoom) {
    if !room.config().randomize {
        let teams = CONFIG
            .game
            .teams
            .iter()
            .map(|(s, col)| (s.clone(), RgbColor::from_hex(col).expect("valid colors")))
            .collect(); // TODO: clean up, don't reinitialize every function call
        room.create_team(&teams).expect("creating initial 1st team");
        room.create_team(&teams).expect("creating initial 2nd team");
    }
}
