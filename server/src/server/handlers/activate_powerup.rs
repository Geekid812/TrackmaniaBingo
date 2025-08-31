use crate::{
    datatypes::Powerup,
    server::{
        context::ClientContext,
        handlers::{error, ok},
    },
};
use serde::Deserialize;
use serde_json::Value;

#[derive(Deserialize, Debug)]
pub struct ActivatePowerup {
    powerup: Powerup,
    board_index: usize,
    forwards: bool,
    player_uid: i32,
}

pub fn handle(ctx: &mut ClientContext, args: ActivatePowerup) -> Value {
    ctx.game_sync();
    if let Some(game) = ctx.game_match() {
        match game.lock().activate_powerup(ctx.profile.uid, args.powerup, args.board_index, args.forwards, args.player_uid) {
            Ok(()) => ok(),
            Err(msg) => error(&msg)
        }
    } else {
        error("not in a game")
    }}
