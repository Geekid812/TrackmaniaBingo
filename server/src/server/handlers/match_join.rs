use serde::{Deserialize, Serialize};

use crate::{
    core::{directory::MATCHES, models::livegame::MatchState},
    server::context::{ClientContext, GameContext},
};

use super::{generic, Request, Response};

#[derive(Deserialize, Debug)]
pub struct JoinMatch {
    uid: String,
}

#[derive(Serialize, Debug)]
pub struct JoinMatchOk {
    pub state: MatchState,
}

#[typetag::deserialize]
impl Request for JoinMatch {
    fn handle(&self, ctx: &mut ClientContext) -> Box<dyn Response> {
        if let Some(room) = ctx.game_room() {
            ctx.trace("already in a room, leaving previous game");
            room.lock().player_remove(ctx.profile.player.uid);
            // TODO: on player removed?
        }

        return if let Some(livematch) = MATCHES.find(self.uid.clone()) {
            let mut lock = livematch.lock();
            if let Err(e) = lock.player_join(&ctx, None) {
                return Box::new(generic::Error {
                    error: format!("{}", e),
                });
            }

            let state = lock.get_state();
            drop(lock);

            ctx.game = Some(GameContext::new(ctx.profile.clone(), &livematch));
            Box::new(JoinMatchOk { state })
        } else {
            Box::new(generic::Error {
                error: format!("match with uid {} not found", self.uid),
            })
        };
    }
}

#[typetag::serialize]
impl Response for JoinMatchOk {}
