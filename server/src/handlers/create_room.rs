use std::sync::Arc;

use serde::{Deserialize, Serialize};

use crate::{
    config::TEAMS,
    context::{ClientContext, GameContext},
    gamecommon::setup_room,
    gamemap,
    gameroom::RoomConfiguration,
    gameteam::GameTeam,
    roomlist,
    util::sink::WriteSink,
};

use super::{generic, Request, Response};

#[derive(Deserialize, Debug)]
pub struct CreateRoom(RoomConfiguration);

#[derive(Serialize, Debug)]
pub struct CreateRoomResponse {
    pub name: String,
    pub join_code: String,
    pub max_teams: usize,
    pub teams: Vec<GameTeam>,
}

#[typetag::deserialize]
impl Request for CreateRoom {
    fn handle(&self, ctx: &mut ClientContext) -> Box<dyn Response> {
        if let Some(room) = ctx.game_room() {
            ctx.trace("already in a room, leaving previous game");
            room.lock().player_remove(&ctx.identity);
            // TODO: on player removed?
        }
        let room_arc = roomlist::create_room(self.0.clone());
        let mut room = room_arc.lock();

        if let Some(err) = gamemap::init_maps(&room_arc, &mut room) {
            roomlist::remove_room(room_arc.clone());
            return Box::new(generic::Error::from(err));
        }

        setup_room(&mut room);
        room.add_player(&ctx.identity, true);
        let game_ctx = GameContext::new(&ctx, &room_arc);
        room.channel()
            .subscribe(WriteSink::Double(Arc::downgrade(&game_ctx.writer)));
        ctx.game = Some(game_ctx);
        Box::new(CreateRoomResponse {
            name: room.name().to_owned(),
            join_code: room.join_code().to_owned(),
            max_teams: TEAMS.len(),
            teams: room.teams(),
        })
    }
}

#[typetag::serialize]
impl Response for CreateRoomResponse {}
