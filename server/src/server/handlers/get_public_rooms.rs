use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::{
    core::{
        directory::{PUB_ROOMS_CHANNEL, ROOMS},
        models::room::NetworkRoom,
    },
    server::{context::ClientContext, handlers::response},
};

#[derive(Deserialize, Debug)]
pub struct GetPublicRooms {}

#[derive(Serialize, Debug)]
pub struct PublicRoomsList {
    pub rooms: Vec<NetworkRoom>,
}

pub fn handle(ctx: &mut ClientContext, _args: GetPublicRooms) -> Value {
    PUB_ROOMS_CHANNEL
        .lock()
        .subscribe(ctx.profile.uid, ctx.writer.clone());

    let rooms = ROOMS
        .lock()
        .values()
        .filter(|r| r.lock().config().public)
        .map(|r| NetworkRoom::from(&*r.lock()))
        .collect();

    response(PublicRoomsList { rooms })
}
