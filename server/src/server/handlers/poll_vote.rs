use crate::server::context::ClientContext;
use serde::Deserialize;

use super::{generic, Request, Response};

#[derive(Deserialize, Debug)]
pub struct SubmitPollVote {
    poll_id: u32,
    choice: usize,
}

#[typetag::deserialize]
impl Request for SubmitPollVote {
    fn handle(&self, ctx: &mut ClientContext) -> Box<dyn Response> {
        ctx.game_sync();
        if let Some(game) = ctx.game_match() {
            let mut lock = game.lock();
            lock.poll_cast_vote(self.poll_id, ctx.profile.uid as u32, self.choice);
        } else {
            return Box::new(generic::Error {
                error: "not in a game".to_owned(),
            });
        }

        Box::new(generic::Ok)
    }
}
