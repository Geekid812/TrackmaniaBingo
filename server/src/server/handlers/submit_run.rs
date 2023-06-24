use crate::{
    core::models::{
        livegame::{MapClaim, Medal},
        player::PlayerRef,
    },
    server::context::ClientContext,
};
use serde::Deserialize;

use super::{generic, Request, Response};

#[derive(Deserialize, Debug)]
pub struct SubmitRun {
    map_uid: String,
    time: u64,
    medal: Medal,
}

#[typetag::deserialize]
impl Request for SubmitRun {
    fn handle(&self, ctx: &mut ClientContext) -> Box<dyn Response> {
        if let Some(game) = ctx.game_match() {
            let claim = MapClaim {
                player: PlayerRef {
                    uid: ctx.profile.player.uid,
                    team: ctx.game.lock().as_ref().unwrap().team(),
                },
                time: self.time,
                medal: self.medal,
            };
            let mut lock = game.lock();
            let cell = lock.get_cell_from_map_uid(self.map_uid.clone());
            if let Some(id) = cell {
                lock.add_submitted_run(id, claim);
            } else {
                return Box::new(generic::Error {
                    error: "invalid map uid".to_owned(),
                });
            }
        } else {
            return Box::new(generic::Error {
                error: "not in a game".to_owned(),
            });
        }

        Box::new(generic::Ok)
    }
}
