use std::collections::HashMap;

use once_cell::sync::Lazy;
use parking_lot::Mutex;

use crate::{context::GameContext, rest::auth::PlayerIdentity};

static LINGERING: Mutex<Lazy<HashMap<PlayerIdentity, GameContext>>> =
    Mutex::new(Lazy::new(|| HashMap::new()));

pub fn add_lingering(identity: &PlayerIdentity, ctx: GameContext) {
    LINGERING.lock().insert(identity.clone(), ctx);
}

pub fn recover(identity: &PlayerIdentity) -> Option<GameContext> {
    LINGERING
        .lock()
        .remove(identity)
        .and_then(|ctx| if ctx.is_alive() { Some(ctx) } else { None })
}
