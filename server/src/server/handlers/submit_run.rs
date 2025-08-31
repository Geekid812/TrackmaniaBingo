use crate::{
    core::models::livegame::MapClaim,
    datatypes::Medal,
    server::{
        context::ClientContext,
        handlers::{error, ok},
    },
};
use chrono::Utc;
use serde::Deserialize;
use serde_json::Value;

#[derive(Deserialize, Debug)]
pub struct SubmitRun {
    tile_index: usize,
    time: u64,
    medal: Medal,
    splits: Vec<u64>,
}

pub fn handle(ctx: &mut ClientContext, args: SubmitRun) -> Value {
    ctx.game_sync();
    if let Some(game) = ctx.game_match() {
        let claim = MapClaim {
            player: ctx.get_player_ref(),
            team_id: ctx.game.as_ref().unwrap().team(),
            time: args.time,
            medal: args.medal,
            splits: args.splits,
            timestamp: Utc::now(),
        };
        let mut lock = game.lock();
        lock.add_submitted_run(args.tile_index, claim);
    } else {
        return error("not in a game");
    }

    ok()
}
