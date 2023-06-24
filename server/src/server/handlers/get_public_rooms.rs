use serde::{Deserialize, Serialize};

use crate::{
    core::{directory::ROOMS, models::room::NetworkRoom},
    server::context::ClientContext,
};

use super::{generic, Request, Response};

#[derive(Deserialize, Debug)]
pub struct GetPublicRooms;

#[derive(Serialize, Debug)]
pub struct PublicRoomsList {
    pub rooms: Vec<NetworkRoom>,
}

#[typetag::deserialize]
impl Request for GetPublicRooms {
    fn handle(&self, _ctx: &mut ClientContext) -> Box<dyn Response> {
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
