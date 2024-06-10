use std::{
    collections::HashMap,
    sync::{Arc, OnceLock},
};

use parking_lot::Mutex;
use tracing::debug;

use crate::{
    core::{
        directory::{Owned, Shared},
        livegame::LiveMatch,
        models::team::TeamIdentifier,
        room::GameRoom,
    },
    datatypes::PlayerRef,
    orm::composed::profile::PlayerProfile,
};

/// Global mapping of all global `PlayerContext` structures by uid.
static CONTEXTS: OnceLock<Mutex<HashMap<i32, Owned<PlayerContext>>>> = OnceLock::new();

/// Get a handle to a player's global context, that is: its main controller interface.
pub fn get_context(uid: i32) -> Owned<PlayerContext> {
    let mut lock = CONTEXTS.get_or_init(|| Mutex::new(HashMap::new())).lock();
    if let Some(ctx) = lock.get(&uid) {
        ctx.clone()
    } else {
        // Context has not been created for this uid, initialize it now
        let ctx = Arc::new(Mutex::new(PlayerContext::new(uid)));
        lock.insert(uid, ctx.clone());
        ctx
    }
}

/// The player context is a facade for handling any kind of operation for a given player.
pub struct PlayerContext {
    pub uid: i32,
}

impl PlayerContext {
    pub fn new(uid: i32) -> Self {
        Self { uid }
    }

    pub fn game_room(&self) -> Option<Owned<GameRoom>> {
        self.room.as_ref().and_then(|roomctx| roomctx.room())
    }

    pub fn game_sync(&mut self) {
        if let Some(game) = self.room.as_ref().and_then(|roomctx| roomctx.game()) {
            self.game = Some(GameContext::new(self.profile.clone(), &game));
        }
    }

    pub fn game_match(&self) -> Option<Owned<LiveMatch>> {
        self.game.as_ref().and_then(|gamectx| gamectx.game_match())
    }

    pub fn get_player_ref(&self) -> PlayerRef {
        PlayerRef {
            uid: self.profile.player.uid as u32,
            name: self.profile.player.username.clone(),
        }
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

impl Drop for PlayerContext {
    fn drop(&mut self) {
        debug!("ClientContext dropped");
        self.room.as_mut().map(|r| r.cleanup());
        self.game.as_mut().map(|g| g.cleanup());
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

    pub fn game(&self) -> Option<Owned<LiveMatch>> {
        self.room.upgrade().and_then(|r| r.lock().get_match())
    }

    pub fn cleanup(&mut self) {
        debug!("RoomContext cleanup");
        if let Some(room) = self.room() {
            let mut lock = room.lock();
            lock.player_remove(self.profile.player.uid);
            lock.check_close();
        }
    }
}

pub struct GameContext {
    game_match: Shared<LiveMatch>,
    team: TeamIdentifier,
}

impl GameContext {
    pub fn new(profile: PlayerProfile, game_match: &Owned<LiveMatch>) -> Self {
        let uid = profile.player.uid;
        Self {
            game_match: Arc::downgrade(game_match),
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

    pub fn cleanup(&mut self) {}
}
