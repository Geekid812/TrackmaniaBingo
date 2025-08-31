use crate::{
    core::events::{game::GameEvent, room::RoomEvent},
    datatypes::{ChatMessage, PlayerRef},
    server::{
        context::ClientContext,
        handlers::{error, ok},
    },
};
use chrono::Utc;
use serde::Deserialize;
use serde_json::Value;

#[derive(Deserialize, Debug)]
pub struct SendChatMessage {
    message: String,
}

fn build_chat_message(message: &str, player: PlayerRef) -> ChatMessage {
    let content;
    let team_message = message.starts_with("/t ");
    if team_message {
        content = message.chars().skip(3).collect();
    } else {
        content = message.to_string();
    }
    ChatMessage {
        uid: player.uid,
        name: player.name,
        title: None,
        content,
        timestamp: Utc::now(),
        team_message,
    }
}

pub fn handle(ctx: &mut ClientContext, args: SendChatMessage) -> Value {
    ctx.game_sync();
    let player = ctx.get_player_ref();
    let message = build_chat_message(&args.message, player);
    let is_team_message = message.team_message;

    if let Some(game) = ctx.game_match() {
        let mut lock = game.lock();
        let event = GameEvent::ChatMessage(message);
        if is_team_message {
            lock.get_team_mut(ctx.game.as_ref().unwrap().team())
                .unwrap()
                .channel
                .broadcast(&event);
        } else {
            lock.channel().broadcast(&event);
        }
    } else if let Some(room) = ctx.game_room() {
        let mut lock = room.lock();
        lock.channel().broadcast(&RoomEvent::ChatMessage(message));
    } else {
        return error("not in a game");
    }

    ok()
}
