/// Model for the creation of a new player entry.
#[derive(Debug)]
pub struct NewPlayer {
    pub account_id: String,
    pub username: String,
    pub country_code: Option<String>,
}
