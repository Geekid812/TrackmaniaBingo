mod models;

pub use models::*;

use super::{execute_with_arguments, get_store, StoreWriteResult};

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
