use crate::{core::team::TeamIdentifier, server::context::ClientContext};
use serde::Deserialize;

use super::{Request, Response};

#[derive(Deserialize, Debug)]
pub struct ChangeTeam {
    team_id: TeamIdentifier,
}

#[typetag::deserialize]
impl Request for ChangeTeam {
    fn handle(&self, ctx: &mut ClientContext) -> Box<dyn Response> {
        if let Some(room) = ctx.game_room() {
            let mut lock = room.lock();
            if lock.change_team(&ctx, self.team_id) {
                lock.room_update();
            } else {
                ctx.trace("invalid team id, ignored");
            }
        } else {
            ctx.trace("not in a room, ignored");
        }
    }
}
