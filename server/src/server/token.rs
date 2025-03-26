use std::collections::HashMap;

use once_cell::sync::Lazy;
use parking_lot::Mutex;

static TOKEN_STORE: Mutex<Lazy<HashMap<String, PlayerIdentifier>>> =
    Mutex::new(Lazy::new(|| HashMap::new()));

/// Find a player matching the given identity token.
pub fn get_player_from_token(token: &str) -> Option<PlayerIdentifier> {
    TOKEN_STORE.lock().get(token).map(PlayerIdentifier::clone)
}

/// Create an identity token which authenticates this player.
pub fn set_player_token(player: PlayerIdentifier, token: String) {
    TOKEN_STORE.lock().insert(token, player);
}

/// Model for a player's uid and username.
#[derive(Debug, Clone)]
pub struct PlayerIdentifier {
    pub uid: i32,
    pub display_name: String,
}
