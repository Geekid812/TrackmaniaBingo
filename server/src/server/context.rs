use std::sync::Arc;

use tracing::debug;

use crate::{
    core::{
        directory::{Owned, Shared},
        livegame::LiveMatch,
        models::team::TeamIdentifier,
        room::GameRoom,
    },
    datatypes::{PlayerProfile, PlayerRef},
    transport::messager::NetMessager,
};

pub struct ClientContext {
    pub room: Option<RoomContext>,
    pub game: Option<GameContext>,
    pub profile: PlayerProfile,
    pub writer: NetMessager,
}

impl ClientContext {
    pub fn new(profile: PlayerProfile, writer: NetMessager) -> Self {
        Self {
            room: None,
            game: None,
            profile,
            writer,
        }
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
            uid: self.profile.uid as u32,
            name: self.profile.name.clone(),
        }
    }

    pub fn trace<M: Into<String>>(&self, message: M) {
        debug!("Trace message: {}", message.into());
    }
}

impl Drop for ClientContext {
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
            lock.player_remove(self.profile.uid);
        }
    }
}

pub struct GameContext {
    game_match: Shared<LiveMatch>,
    team: TeamIdentifier,
}

impl GameContext {
    pub fn new(profile: PlayerProfile, game_match: &Owned<LiveMatch>) -> Self {
        let uid = profile.uid;
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
