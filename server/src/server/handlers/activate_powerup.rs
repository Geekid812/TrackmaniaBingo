use crate::{
    core::models::livegame::MapClaim,
    server::{
        context::ClientContext,
        handlers::{error, ok},
    },
};
use serde::Deserialize;
use serde_json::Value;

#[derive(Deserialize, Debug)]
pub struct ActivatePowerup {
    board_index: usize,
    forwards: bool,
}

pub fn handle(ctx: &mut ClientContext, args: ActivatePowerup) -> Value {
    ctx.game_sync();
    if let Some(game) = ctx.game_match() {
        
    } else {
        return error("not in a game");
    }

    ok()
}
