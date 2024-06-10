use serde::Deserialize;

use crate::{core::directory::PUB_ROOMS_CHANNEL, server::context::PlayerContext};

use super::{generic, Request, Response};

#[derive(Deserialize, Debug)]
pub struct UnsubscribeRoomlist;

#[typetag::deserialize]
impl Request for UnsubscribeRoomlist {
    fn handle(&self, ctx: &mut PlayerContext) -> Box<dyn Response> {
        PUB_ROOMS_CHANNEL.lock().unsubscribe(ctx.profile.player.uid);
        Box::new(generic::Ok)
    }
}
