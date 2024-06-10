use serde::{Deserialize, Serialize};

use crate::{
    core::{
        directory::{PUB_ROOMS_CHANNEL, ROOMS},
        models::room::NetworkRoom,
    },
    server::context::PlayerContext,
};

use super::{Request, Response};

#[derive(Deserialize, Debug)]
pub struct GetPublicRooms;

#[derive(Serialize, Debug)]
pub struct PublicRoomsList {
    pub rooms: Vec<NetworkRoom>,
}

#[typetag::deserialize]
impl Request for GetPublicRooms {
    fn handle(&self, ctx: &mut PlayerContext) -> Box<dyn Response> {
        PUB_ROOMS_CHANNEL
            .lock()
            .subscribe(ctx.profile.player.uid, ctx.writer.clone());
        let rooms = ROOMS
            .lock()
            .values()
            .filter(|r| r.lock().config().public)
            .map(|r| NetworkRoom::from(&*r.lock()))
            .collect();
        Box::new(PublicRoomsList { rooms })
    }
}

#[typetag::serialize]
impl Response for PublicRoomsList {}
