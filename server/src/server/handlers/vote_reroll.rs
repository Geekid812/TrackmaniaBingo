use crate::server::{
    context::ClientContext,
    handlers::{error, ok},
};
use serde::Deserialize;
use serde_json::Value;

#[derive(Deserialize, Debug)]
pub struct CastRerollVote {
    cell_id: usize,
}

pub fn handle(ctx: &mut ClientContext, args: CastRerollVote) -> Value {
    ctx.game_sync();
    if let Some(game) = ctx.game_match() {
        let mut lock = game.lock();
        let result = lock.submit_reroll_vote(args.cell_id, ctx.get_player_ref());
        if let Err(e) = result {
            return error(&e.to_string());
        }
    } else {
        return error("not in a game");
    }

    ok()
}
