use crate::server::context::ClientContext;
use serde::Deserialize;

use super::{generic, Request, Response};

#[derive(Deserialize, Debug)]
pub struct CastRerollVote {
    cell_id: usize,
}

#[typetag::deserialize]
impl Request for CastRerollVote {
    fn handle(&self, ctx: &mut ClientContext) -> Box<dyn Response> {
        ctx.game_sync();
        if let Some(game) = ctx.game_match() {
            let mut lock = game.lock();
            let result = lock.submit_reroll_vote(self.cell_id, ctx.profile.player.uid);
            if let Err(e) = result {
                return Box::new(generic::Error {
                    error: e.to_string(),
                });
            }
        } else {
            return Box::new(generic::Error {
                error: "not in a game".to_owned(),
            });
        }

        Box::new(generic::Ok)
    }
}
