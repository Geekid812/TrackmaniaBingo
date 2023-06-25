use std::sync::Arc;

use tracing::debug;

use crate::{
    core::{
        directory::{Owned, Shared},
        livegame::LiveMatch,
        models::team::TeamIdentifier,
        room::GameRoom,
    },
    orm::composed::profile::PlayerProfile,
    transport::Tx,
};

pub struct ClientContext {
    pub room: Owned<Option<RoomContext>>,
    pub game: Owned<Option<GameContext>>,
    pub profile: PlayerProfile,
    pub writer: Arc<Tx>,
}

impl ClientContext {
    pub fn new(
        profile: PlayerProfile,
        room: Owned<Option<RoomContext>>,
        game: Owned<Option<GameContext>>,
        writer: Arc<Tx>,
    ) -> Self {
        Self {
            room,
            game,
            profile,
            writer,
        }
    }

    pub fn game_room(&self) -> Option<Owned<GameRoom>> {
        self.room.lock().as_ref().and_then(|roomctx| roomctx.room())
    }

    pub fn game_match(&self) -> Option<Owned<LiveMatch>> {
        self.game
            .lock()
            .as_ref()
            .and_then(|gamectx| gamectx.game_match())
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

pub struct RoomContext {
    room: Shared<GameRoom>,
    profile: PlayerProfile,
}

impl RoomContext {
    pub fn new(profile: PlayerProfile, room: &Owned<GameRoom>) -> Self {
        Self {
            room: Arc::downgrade(room),
            profile,
        }
    }

    pub fn is_alive(&self) -> bool {
        self.room.strong_count() > 0
    }

    pub fn room(&self) -> Option<Owned<GameRoom>> {
        self.room.upgrade()
    }
}

impl Drop for RoomContext {
    fn drop(&mut self) {
        debug!("RoomContext dropped");
        if let Some(room) = self.room() {
            let mut lock = room.lock();
            lock.player_remove(self.profile.player.uid);
            lock.check_close();
        }
    }
}

pub struct GameContext {
    game_match: Shared<LiveMatch>,
    profile: PlayerProfile,
    team: TeamIdentifier,
}

impl GameContext {
    pub fn new(profile: PlayerProfile, game_match: &Owned<LiveMatch>) -> Self {
        let uid = profile.player.uid;
        Self {
            game_match: Arc::downgrade(game_match),
            profile,
            team: game_match
                .lock()
                .get_player_team(uid)
                .expect("GameContext not initialized because this player is not in a team"),
        }
    }

    pub fn is_alive(&self) -> bool {
        self.game_match.strong_count() > 0
    }

    pub fn game_match(&self) -> Option<Owned<LiveMatch>> {
        self.game_match.upgrade()
    }

    pub fn team(&self) -> TeamIdentifier {
        self.team
    }
}

impl Drop for GameContext {
    fn drop(&mut self) {
        debug!("GameContext dropped");
        //if let Some(room) = self.game_match() {
        //    // TODO: room.lock().player_remove(self.profile.player.uid);
        //}
    }
}
