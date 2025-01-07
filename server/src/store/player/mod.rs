mod models;

use crate::datatypes::{PlayerProfile, PlayerRef};

use super::{
    execute_with_arguments, get_store, query_with_arguments, StoreReadResult, StoreWriteResult,
};
pub use models::*;
use sqlx::Row;

/// Create a new player record, or update it if there already exists a player record with the specified account ID.
pub async fn create_or_update_player(player: NewPlayer) -> StoreWriteResult {
    execute_with_arguments(
    get_store(),
    "INSERT INTO players(account_id, username, country_code, client_token) VALUES (?, ?, ?, ?) ON CONFLICT(account_id) DO UPDATE SET client_token=excluded.client_token, username=excluded.username, country_code=excluded.country_code",
    |query| {
        query.bind(player.account_id)
        .bind(player.username)
        .bind(player.country_code)
        .bind(player.client_token)
    }).await.map(|_| ())
}

/// Find a player matching the given identity token.
pub async fn get_player_from_token(token: &str) -> StoreReadResult<PlayerIdentifier> {
    query_with_arguments(
        get_store(),
        "SELECT uid, username FROM players WHERE client_token = ?",
        |query| query.bind(token),
    )
    .await
    .map(|row| PlayerIdentifier {
        uid: row.get(0),
        display_name: row.get(1),
    })
}

pub async fn get_player_profile(uid: i32) -> StoreReadResult<PlayerProfile> {
    query_with_arguments(get_store(),
    "SELECT username, account_id, created_at, last_played_at, country_code, title, games_played, games_won FROM player_summary WHERE uid = ?", 
    |query| query.bind(uid))
    .await
    .map(|row| PlayerProfile { uid, name: row.get(0) , account_id: row.get(1), created_at: row.get(2), last_played_at: row.get(3), country_code: row.get(4), title: row.get(5), games_played: row.get(6), games_won: row.get(7), score: 1000 })
}
