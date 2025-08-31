use serde::Deserialize;
use serde_json::Value;

use crate::{
    core::directory::PUB_ROOMS_CHANNEL,
    server::{context::ClientContext, handlers::ok},
};

#[derive(Deserialize, Debug)]
pub struct UnsubscribeRoomlist {}

pub fn handle(ctx: &mut ClientContext, _args: UnsubscribeRoomlist) -> Value {
    PUB_ROOMS_CHANNEL.lock().unsubscribe(ctx.profile.uid);
    ok()
}
