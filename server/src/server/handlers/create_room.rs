use serde::{Deserialize, Serialize};

use crate::{
    core::{directory, gamecommon::setup_room, models::team::BaseTeam, room::GameRoom},
    datatypes::{MatchConfiguration, RoomConfiguration},
    server::context::{ClientContext, RoomContext},
};

use super::{Request, Response};

#[derive(Deserialize, Debug)]
pub struct CreateRoom {
    config: RoomConfiguration,
    match_config: MatchConfiguration,
}

#[derive(Serialize, Debug)]
pub struct CreateRoomResponse {
    pub name: String,
    pub join_code: String,
    pub max_teams: usize,
    pub teams: Vec<BaseTeam>,
}

#[typetag::deserialize]
impl Request for CreateRoom {
    fn handle(&self, ctx: &mut ClientContext) -> Box<dyn Response> {
        if let Some(room) = ctx.game_room() {
            ctx.trace("already in a room, leaving previous game");
            room.lock().player_remove(ctx.profile.uid);
            // ctx.room;
        }
        let roomcode = directory::get_new_roomcode();
        let new_room = GameRoom::create(
            self.config.clone(),
            self.match_config.clone(),
            roomcode.clone(),
        );
        directory::ROOMS.insert(roomcode, new_room.clone());
        setup_room(&new_room);

        let mut room = new_room.lock();
        let room_ctx = Some(RoomContext::new(ctx.profile.clone(), &new_room));
        ctx.room = room_ctx;
        room.add_player(&ctx, &ctx.profile, true);
        if room.config().public {
            directory::send_room_visibility(&room, true);
        }

        Box::new(CreateRoomResponse {
            name: room.name().to_owned(),
            join_code: room.join_code().to_owned(),
            max_teams: crate::CONFIG.game.teams.len(),
            teams: room.teams().into_iter().map(BaseTeam::to_owned).collect(),
        })
    }
}

#[typetag::serialize]
impl Response for CreateRoomResponse {}
