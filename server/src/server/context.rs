use std::sync::{Arc, Weak};

use tracing::debug;

use crate::{
    core::roomlist::{OwnedRoom, SharedRoom},
    orm::composed::profile::PlayerProfile,
    transport::Tx,
};

pub struct ClientContext {
    pub game: Option<GameContext>,
    pub profile: PlayerProfile,
    pub writer: Arc<Tx>,
}

impl ClientContext {
    pub fn new(profile: PlayerProfile, game: Option<GameContext>, writer: Arc<Tx>) -> Self {
        Self {
            game,
            profile,
            writer,
        }
    }

    pub fn game_room(&self) -> Option<OwnedRoom> {
        self.game.as_ref().and_then(|gamectx| gamectx.room())
    }

    pub fn trace<M: Into<String>>(&self, message: M) {
        if let Ok(text) = serde_json::to_string(&message.into()) {
            drop(
                self.writer
                    .send(format!("{{\"event\":\"Trace\",\"value\":{}}}", text)),
            );
        }
    }
}

pub struct GameContext {
    room: SharedRoom,
    profile: PlayerProfile,
    pub writer: Arc<Weak<Tx>>,
}

impl GameContext {
    pub fn new(ctx: &ClientContext, room: &OwnedRoom) -> Self {
        Self {
            room: Arc::downgrade(room),
            profile: ctx.profile.clone(),
            writer: Arc::new(Arc::downgrade(&ctx.writer)),
        }
    }
    pub fn is_alive(&self) -> bool {
        self.room.strong_count() > 0
    }

    pub fn room(&self) -> Option<OwnedRoom> {
        self.room.upgrade()
    }
}

impl Drop for GameContext {
    fn drop(&mut self) {
        debug!("dropped");
        if let Some(room) = self.room() {
            room.lock().player_remove(self.profile.player.uid);
        }
    }
}
