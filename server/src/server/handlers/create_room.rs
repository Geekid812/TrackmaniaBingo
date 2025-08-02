use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::{
    config,
    core::{directory, gamecommon::setup_room, models::team::BaseTeam, room::GameRoom},
    datatypes::{MatchConfiguration, RoomConfiguration},
    server::{
        context::{ClientContext, RoomContext},
        handlers::{error, response},
    },
};

#[derive(Deserialize, Debug)]
pub struct CreateRoom {
    config: RoomConfiguration,
    match_config: MatchConfiguration,
    teams: Vec<BaseTeam>,
}

#[derive(Serialize, Debug)]
pub struct CreateRoomResponse {
    pub name: String,
    pub join_code: String,
    pub max_teams: usize,
    pub teams: Vec<BaseTeam>,
}

pub fn handle(ctx: &mut ClientContext, args: CreateRoom) -> Value {
    if args.teams.len() < 2 {
        return error(
            "Not enough teams to create a new room. Please configure at least 2 teams in the Teams Editor."
        );
    }

    if let Some(room) = ctx.game_room() {
        ctx.trace("already in a room, leaving previous game");
        room.lock().player_remove(ctx.profile.uid);
    }

    let roomcode = directory::get_new_roomcode();
    let new_room = GameRoom::create(
        args.config.clone(),
        args.match_config.clone(),
        roomcode.clone(),
    );
    directory::ROOMS.insert(roomcode, new_room.clone());
    setup_room(&new_room, &args.teams);

    let mut room = new_room.lock();
    let room_ctx = Some(RoomContext::new(ctx.profile.clone(), &new_room));
    ctx.room = room_ctx;
    room.add_player(&ctx, &ctx.profile, true);
    if room.config().public {
        directory::send_room_visibility(&room, true);
    }

    response(CreateRoomResponse {
        name: room.name().to_owned(),
        join_code: room.join_code().to_owned(),
        max_teams: config::get_integer("behavior.max_teams").unwrap_or(6) as usize,
        teams: room.teams().into_iter().map(BaseTeam::to_owned).collect(),
    })
}
