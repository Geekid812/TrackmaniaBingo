use crate::{core::models::team::TeamIdentifier, server::context::ClientContext};
use serde::Deserialize;

use super::{generic, Request, Response};

#[derive(Deserialize, Debug)]
pub struct ChangeTeam {
    team_id: TeamIdentifier,
}

#[typetag::deserialize]
impl Request for ChangeTeam {
    fn handle(&self, ctx: &mut ClientContext) -> Box<dyn Response> {
        if let Some(room) = ctx.game_room() {
            let mut lock = room.lock();
            lock.change_team(ctx.profile.player.uid, self.team_id);
        } else {
            ctx.trace("not in a room, ignored");
        }

        Box::new(generic::Ok)
    }
}
