use crate::server::{
    context::ClientContext,
    handlers::{error, ok},
};
use serde::Deserialize;
use serde_json::Value;

#[derive(Deserialize, Debug)]
pub struct SubmitPollVote {
    poll_id: u32,
    choice: usize,
}

pub fn handle(ctx: &mut ClientContext, args: SubmitPollVote) -> Value {
    ctx.game_sync();
    if let Some(game) = ctx.game_match() {
        let mut lock = game.lock();
        lock.poll_cast_vote(args.poll_id, ctx.profile.uid as u32, args.choice);
    } else {
        return error("not in a game");
    }

    ok()
}
