use std::collections::HashMap;

use once_cell::sync::Lazy;
use parking_lot::Mutex;

static TOKEN_STORE: Mutex<Lazy<HashMap<String, i32>>> =
    Mutex::new(Lazy::new(|| HashMap::new()));

/// Find a player UID matching the given identity token.
pub fn get_player_from_token(token: &str) -> Option<i32> {
    TOKEN_STORE.lock().get(token).copied()
}

/// Create an identity token which authenticates this player.
pub fn set_player_token(uid: i32, token: String) {
    TOKEN_STORE.lock().insert(token, uid);
}
