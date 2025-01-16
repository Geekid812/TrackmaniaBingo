/// Model for the creation of a new player entry.
#[derive(Debug)]
pub struct NewPlayer {
    pub account_id: String,
    pub username: String,
    pub client_token: String,
    pub country_code: Option<String>,
}

/// Model for a player's uid and username.
#[derive(Debug)]
pub struct PlayerIdentifier {
    pub uid: i32,
    pub display_name: String,
}
