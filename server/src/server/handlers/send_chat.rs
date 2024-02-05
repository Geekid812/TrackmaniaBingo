use crate::{
    core::events::{game::GameEvent, room::RoomEvent},
    datatypes::{ChatMessage, PlayerRef},
    server::context::ClientContext,
};
use chrono::Utc;
use serde::Deserialize;

use super::{generic, Request, Response};

#[derive(Deserialize, Debug)]
pub struct SendChatMessage {
    message: String,
}

fn build_chat_message(message: &str, player: PlayerRef) -> ChatMessage {
    ChatMessage {
        uid: player.uid,
        name: player.name,
        title: None,
        content: message.to_string(),
        timestamp: Utc::now(),
        team_message: false,
    }
}

#[typetag::deserialize]
impl Request for SendChatMessage {
    fn handle(&self, ctx: &mut ClientContext) -> Box<dyn Response> {
        ctx.game_sync();
        let message = build_chat_message(&self.message, ctx.get_player_ref());
        if let Some(game) = ctx.game_match() {
            let mut lock = game.lock();
            lock.channel().broadcast(&GameEvent::ChatMessage(message));
        } else if let Some(room) = ctx.game_room() {
            let mut lock = room.lock();
            lock.channel().broadcast(&RoomEvent::ChatMessage(message));
        } else {
            return Box::new(generic::Error {
                error: "not in a game".to_owned(),
            });
        }

        Box::new(generic::Ok)
    }
}
