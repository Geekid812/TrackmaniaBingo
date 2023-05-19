use serde::{Deserialize, Serialize};

use crate::{
    core::{
        gamecommon::setup_room,
        livegame::MatchConfiguration,
        room::{GameRoom, NetworkTeam, RoomConfiguration},
        roomlist,
    },
    //gamemap,
    server::context::{ClientContext, GameContext},
};

use super::{generic, Request, Response};

#[derive(Deserialize, Debug)]
pub struct CreateRoom {
    name: String,
    #[serde(flatten)]
    config: RoomConfiguration,
    #[serde(flatten)]
    matchconfig: MatchConfiguration,
}

#[derive(Serialize, Debug)]
pub struct CreateRoomResponse {
    pub name: String,
    pub join_code: String,
    pub max_teams: usize,
    pub teams: Vec<NetworkTeam>,
}

#[typetag::deserialize]
impl Request for CreateRoom {
    fn handle(&self, ctx: &mut ClientContext) -> Box<dyn Response> {
        if let Some(room) = ctx.game_room() {
            ctx.trace("already in a room, leaving previous game");
            room.lock().player_remove(ctx.profile.player.uid);
            // TODO: on player removed?
        }
        let roomcode = roomlist::get_new_roomcode();
        let new_room = GameRoom::create(self.config, self.matchconfig, self.name, roomcode);
        let room_arc = roomlist::register_room(new_room);
        let mut room = room_arc.lock();

        //if let Some(err) = gamemap::init_maps(&room_arc, &mut room) {
        //    roomlist::remove_room(room_arc.clone());
        //    return Box::new(generic::Error::from(err));
        //}

        setup_room(&mut room);
        room.add_player(&ctx.profile, true);
        let game_ctx = GameContext::new(&ctx, &room_arc);
        room.channel()
            .subscribe(ctx.profile.player.account_id, ctx.writer);
        ctx.game = Some(game_ctx);
        Box::new(CreateRoomResponse {
            name: room.name().to_owned(),
            join_code: room.join_code().to_owned(),
            max_teams: crate::CONFIG.game.teams.len(),
            teams: room.teams(),
        })
    }
}

#[typetag::serialize]
impl Response for CreateRoomResponse {}
