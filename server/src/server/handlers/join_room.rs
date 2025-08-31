use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::{
    core::{directory::ROOMS, models::room::RoomTeam, room::JoinRoomError},
    datatypes::{MatchConfiguration, RoomConfiguration},
    server::{
        context::{ClientContext, RoomContext},
        handlers::{error, response},
    },
};

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
    pub is_host: bool,
}

pub fn handle(ctx: &mut ClientContext, args: JoinRoom) -> Value {
    if let Some(room) = ctx.game_room() {
        ctx.trace("already in a room, leaving previous game");
        room.lock().player_remove(ctx.profile.uid);
    }

    if let Some(room) = ROOMS.find(args.join_code.clone()) {
        let mut lock = room.lock();
        let is_host = match lock.player_join(&ctx, &ctx.profile) {
            Ok(host) => host,
            Err(e) => return error(&format!("{}", e)),
        };
        ctx.room = Some(RoomContext::new(ctx.profile.clone(), &room));

        response(JoinRoomResponse {
            config: lock.config().clone(),
            match_config: lock.matchconfig().clone(),
            match_uid: lock.match_uid(),
            teams: lock.teams_as_model(),
            is_host
        })
    } else {
        error(&format!("{}", JoinRoomError::DoesNotExist(args.join_code)))
    }
}
