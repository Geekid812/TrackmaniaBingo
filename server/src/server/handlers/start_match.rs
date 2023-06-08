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
            lock.start_match();
        } else {
            ctx.trace("not in a room, ignored");
        }
        Box::new(generic::Ok)
    }
}
