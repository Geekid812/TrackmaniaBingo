use serde::Deserialize;
use serde_json::Value;

use crate::{
    datatypes::{MatchConfiguration, RoomConfiguration},
    server::{
        context::ClientContext,
        handlers::{error, ok},
    },
};

#[derive(Deserialize, Debug)]
pub struct EditConfig {
    config: RoomConfiguration,
    match_config: MatchConfiguration,
}

pub fn handle(ctx: &mut ClientContext, args: EditConfig) -> Value {
    if let Some(room) = ctx.game_room() {
        let mut lock = room.lock();
        if !lock.get_player(ctx.profile.uid).unwrap().operator {
            return error("You are not a room operator.");
        }

        lock.set_configs(args.config, args.match_config);
        ok()
    } else {
        error("Player is not in a room.")
    }
}
