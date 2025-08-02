use crate::{
    core::models::team::BaseTeam,
    server::{
        context::ClientContext,
        handlers::{error, ok},
    },
};
use serde::Deserialize;
use serde_json::Value;

#[derive(Deserialize, Debug)]
pub struct CreateTeam {
    team: BaseTeam,
}

pub fn handle(ctx: &mut ClientContext, args: CreateTeam) -> Value {
    if let Some(room) = ctx.game_room() {
        let mut lock = room.lock();
        if !lock.get_player(ctx.profile.uid).unwrap().operator {
            return error("You are not a room operator.");
        }

        if let Err(e) = lock.create_team(args.team.name.clone(), args.team.color) {
            return error(&e.to_string());
        }
    } else {
        return error("Player is not in a room.");
    }

    ok()
}
