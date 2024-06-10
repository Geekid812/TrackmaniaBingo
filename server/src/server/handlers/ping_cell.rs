use crate::{core::events::game::GameEvent, server::context::PlayerContext};
use serde::Deserialize;

use super::{generic, Request, Response};

#[derive(Deserialize, Debug)]
pub struct PingCell {
    cell_id: usize,
}

#[typetag::deserialize]
impl Request for PingCell {
    fn handle(&self, ctx: &mut PlayerContext) -> Box<dyn Response> {
        ctx.game_sync();
        if let Some(game) = ctx.game_match() {
            let mut lock = game.lock();
            lock.channel().broadcast(&GameEvent::CellPinged {
                team: ctx.game.as_ref().unwrap().team(),
                cell_id: self.cell_id,
                player: ctx.get_player_ref(),
            });
        } else {
            return Box::new(generic::Error {
                error: "not in a game".to_owned(),
            });
        }

        Box::new(generic::Ok)
    }
}
