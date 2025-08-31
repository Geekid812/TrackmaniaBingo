use crate::{
    core::models::team::TeamIdentifier,
    server::{
        context::ClientContext,
        handlers::{error, ok},
    },
};
use serde::Deserialize;
use serde_json::Value;

#[derive(Deserialize, Debug)]
pub struct ChangePlayerTeam {
    player_uid: i32,
    team_id: TeamIdentifier,
}

pub fn handle(ctx: &mut ClientContext, args: ChangePlayerTeam) -> Value {
    if let Some(room) = ctx.game_room() {
        let mut lock = room.lock();
        if !lock.get_player(ctx.profile.uid).unwrap().operator {
            return error("You are not a room operator.");
        }

        lock.change_team(args.player_uid, args.team_id);
    } else {
        ctx.trace("not in a room, ignored");
    }

    ok()
}
