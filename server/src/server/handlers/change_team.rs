use crate::{core::models::team::TeamIdentifier, server::{context::ClientContext, handlers::{error, ok}}};
use serde::Deserialize;
use serde_json::Value;

#[derive(Deserialize, Debug)]
pub struct ChangeTeam {
    team_id: TeamIdentifier,
}

pub fn handle(ctx: &mut ClientContext, args: ChangeTeam) -> Value {
    if let Some(room) = ctx.game_room() {
        let mut lock = room.lock();
        if lock.config().host_control {
            return error("You cannot change your own team in a host-controlled room.");
        }
    
        lock.change_team(ctx.profile.uid, args.team_id);
    } else {
        ctx.trace("not in a room, ignored");
    }
    
    ok()
}
