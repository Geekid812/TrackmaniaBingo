use crate::server::context::PlayerContext;
use serde::Deserialize;

use super::{generic, Request, Response};

#[derive(Deserialize, Debug)]
pub struct ReloadMaps;

#[typetag::deserialize]
impl Request for ReloadMaps {
    fn handle(&self, ctx: &mut PlayerContext) -> Box<dyn Response> {
        if let Some(room) = ctx.game_room() {
            let mut lock = room.lock();
            if !lock.get_player(ctx.profile.player.uid).unwrap().operator {
                return Box::new(generic::Error {
                    error: "You are not a room operator.".to_owned(),
                });
            }
            lock.reload_maps();
        } else {
            return Box::new(generic::Error {
                error: "Player is not in a room.".to_owned(),
            });
        }

        Box::new(generic::Ok)
    }
}
