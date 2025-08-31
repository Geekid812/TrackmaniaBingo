use serde::Deserialize;
use serde_json::Value;

use crate::server::{
    context::ClientContext,
    handlers::{error, ok},
};

#[derive(Deserialize, Debug)]
pub struct StartMatch {}

pub fn handle(ctx: &mut ClientContext, _args: StartMatch) -> Value {
    if let Some(room) = ctx.game_room() {
        let mut lock = room.lock();
        if !lock.get_player(ctx.profile.uid).unwrap().operator {
            return error("You are not a room operator.");
        }

        if let Err(err) = lock.check_start_match() {
            return error(&err.to_string());
        }
    } else {
        ctx.trace("not in a room, ignored");
    }

    ok()
}
