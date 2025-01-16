use crate::{
    core::models::livegame::MapClaim,
    datatypes::Medal,
    server::context::ClientContext,
};
use serde::Deserialize;

use super::{generic, Request, Response};

#[derive(Deserialize, Debug)]
pub struct SubmitRun {
    tile_index: usize,
    time: u64,
    medal: Medal,
}

#[typetag::deserialize]
impl Request for SubmitRun {
    fn handle(&self, ctx: &mut ClientContext) -> Box<dyn Response> {
        ctx.game_sync();
        if let Some(game) = ctx.game_match() {
            let claim = MapClaim {
                player: ctx.get_player_ref(),
                team_id: ctx.game.as_ref().unwrap().team(),
                time: self.time,
                medal: self.medal,
            };
            let mut lock = game.lock();
            lock.add_submitted_run(self.tile_index, claim);
        } else {
            return Box::new(generic::Error {
                error: "not in a game".to_owned(),
            });
        }

        Box::new(generic::Ok)
    }
}
