use crate::{context::ClientContext, gameteam::TeamIdentifier};
use serde::Deserialize;

use super::ClientEvent;

#[derive(Deserialize, Debug)]
pub struct ChangeTeam {
    team_id: TeamIdentifier,
}

#[typetag::deserialize]
impl ClientEvent for ChangeTeam {
    fn handle(&self, ctx: &mut ClientContext) {
        if let Some(room) = ctx.game_room() {
            let mut lock = room.lock();
            if lock.change_team(&ctx.identity, self.team_id) {
                lock.room_update();
            } else {
                ctx.trace("invalid team id, ignored");
            }
        } else {
            ctx.trace("not in a room, ignored");
        }
    }
}
