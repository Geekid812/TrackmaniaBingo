use crate::{core::models::team::TeamIdentifier, server::context::ClientContext};
use serde::Deserialize;

use super::{generic, Request, Response};

#[derive(Deserialize, Debug)]
pub struct ChangePlayerTeam {
    player_uid: i32,
    team_id: TeamIdentifier,
}

#[typetag::deserialize]
impl Request for ChangePlayerTeam {
    fn handle(&self, ctx: &mut ClientContext) -> Box<dyn Response> {
        if let Some(room) = ctx.game_room() {
            let mut lock = room.lock();
            if !lock.get_player(ctx.profile.uid).unwrap().operator {
                return Box::new(generic::Error {
                    error: "You are not a room operator.".to_owned(),
                });
            }

            lock.change_team(self.player_uid, self.team_id);
        } else {
            ctx.trace("not in a room, ignored");
        }

        Box::new(generic::Ok)
    }
}
