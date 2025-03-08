use crate::{core::models::team::BaseTeam, server::context::ClientContext};
use serde::Deserialize;

use super::{generic, Request, Response};

#[derive(Deserialize, Debug)]
pub struct CreateTeam {
    team: BaseTeam,
}

#[typetag::deserialize]
impl Request for CreateTeam {
    fn handle(&self, ctx: &mut ClientContext) -> Box<dyn Response> {
        if let Some(room) = ctx.game_room() {
            let mut lock = room.lock();
            if !lock.get_player(ctx.profile.uid).unwrap().operator {
                return Box::new(generic::Error {
                    error: "You are not a room operator.".to_owned(),
                });
            }

            if let Err(e) = lock.create_team(self.team.name.clone(), self.team.color) {
                return Box::new(generic::Error {
                    error: e.to_string(),
                });
            }
        } else {
            return Box::new(generic::Error {
                error: "Player is not in a room.".to_owned(),
            });
        }

        Box::new(generic::Ok)
    }
}
