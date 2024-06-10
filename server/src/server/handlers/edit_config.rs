use serde::Deserialize;

use crate::{
    datatypes::{MatchConfiguration, RoomConfiguration},
    server::context::PlayerContext,
};

use super::{generic, Request, Response};

#[derive(Deserialize, Debug)]
pub struct EditConfig {
    config: RoomConfiguration,
    match_config: MatchConfiguration,
}

#[typetag::deserialize]
impl Request for EditConfig {
    fn handle(&self, ctx: &mut PlayerContext) -> Box<dyn Response> {
        if let Some(room) = ctx.game_room() {
            let mut lock = room.lock();
            if !lock.get_player(ctx.profile.player.uid).unwrap().operator {
                return Box::new(generic::Error {
                    error: "You are not a room operator.".to_owned(),
                });
            }

            lock.set_configs(self.config.clone(), self.match_config.clone());
            Box::new(generic::Ok)
        } else {
            Box::new(generic::Error {
                error: "Player is not in a room.".to_owned(),
            })
        }
    }
}
