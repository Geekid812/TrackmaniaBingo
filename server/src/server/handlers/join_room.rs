use serde::{Deserialize, Serialize};

use crate::{
    core::{directory::ROOMS, models::room::RoomTeam, room::JoinRoomError},
    datatypes::{MatchConfiguration, RoomConfiguration},
    server::context::{ClientContext, RoomContext},
};

use super::{generic, Request, Response};

#[derive(Deserialize, Debug)]
pub struct JoinRoom {
    join_code: String,
}

#[derive(Serialize, Debug)]
pub struct JoinRoomResponse {
    pub config: RoomConfiguration,
    pub match_config: MatchConfiguration,
    pub match_uid: Option<String>,
    pub teams: Vec<RoomTeam>,
}

#[typetag::deserialize]
impl Request for JoinRoom {
    fn handle(&self, ctx: &mut ClientContext) -> Box<dyn Response> {
        if let Some(room) = ctx.game_room() {
            ctx.trace("already in a room, leaving previous game");
            room.lock().player_remove(ctx.profile.uid);
            // TODO: on player removed?
        }

        return if let Some(room) = ROOMS.find(self.join_code.clone()) {
            let mut lock = room.lock();
            if let Err(e) = lock.player_join(&ctx, &ctx.profile) {
                return Box::new(generic::Error {
                    error: format!("{}", e),
                });
            }
            ctx.room = Some(RoomContext::new(ctx.profile.clone(), &room));
            Box::new(JoinRoomResponse {
                config: lock.config().clone(),
                match_config: lock.matchconfig().clone(),
                match_uid: lock.match_uid(),
                teams: lock.teams_as_model(),
            })
        } else {
            Box::new(generic::Error {
                error: format!("{}", JoinRoomError::DoesNotExist(self.join_code.clone())),
            })
        };
    }
}

#[typetag::serialize]
impl Response for JoinRoomResponse {}
