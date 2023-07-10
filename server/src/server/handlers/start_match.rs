use serde::Deserialize;

use crate::server::context::ClientContext;

use super::{generic, Request, Response};

#[derive(Deserialize, Debug)]
pub struct StartMatch;

#[typetag::deserialize]
impl Request for StartMatch {
    fn handle(&self, ctx: &mut ClientContext) -> Box<dyn Response> {
        if let Some(room) = ctx.game_room() {
            let mut lock = room.lock();
            if !lock.get_player(ctx.profile.player.uid).unwrap().operator {
                return Box::new(generic::Error {
                    error: "You are not a room operator.".to_owned(),
                });
            }

            if let Err(error) = lock.check_start_match() {
                return Box::new(generic::Error {
                    error: error.to_string(),
                });
            }
        } else {
            ctx.trace("not in a room, ignored");
        }
        Box::new(generic::Ok)
    }
}
