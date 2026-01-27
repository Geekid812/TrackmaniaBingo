use crate::{
    core::models::map::GameMap,
    server::{
        context::ClientContext,
        handlers::{error, response},
    },
};
use serde::{Deserialize, Serialize};
use serde_json::Value;

#[derive(Deserialize, Debug)]
pub struct GetDiceChoices {}

#[derive(Serialize, Debug)]
pub struct GetDiceResponse {
    pub maps: Vec<GameMap>,
}

pub fn handle(ctx: &mut ClientContext, _args: GetDiceChoices) -> Value {
    ctx.game_sync();
    if let Some(game) = ctx.game_match() {
        response(GetDiceResponse {
            maps: game.lock().get_dice_choices(),
        })
    } else {
        error("not in a game")
    }
}
