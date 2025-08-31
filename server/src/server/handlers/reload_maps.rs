use crate::server::{
    context::ClientContext,
    handlers::{error, ok},
};
use serde::Deserialize;
use serde_json::Value;

#[derive(Deserialize, Debug)]
pub struct ReloadMaps {}

pub fn handle(ctx: &mut ClientContext, _args: ReloadMaps) -> Value {
    if let Some(room) = ctx.game_room() {
        let mut lock = room.lock();
        if !lock.get_player(ctx.profile.uid).unwrap().operator {
            return error("You are not a room operator.");
        }
        lock.reload_maps();
    } else {
        return error("Player is not in a room.");
    }

    ok()
}
