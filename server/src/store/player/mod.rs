mod models;

use crate::datatypes::PlayerProfile;

use super::{get_store, query_with_arguments, StoreResult};
use chrono::{DateTime, Utc};
pub use models::*;
use sqlx::Row;

/// Create a new player record, or update it if there already exists a player record with the specified account ID.
pub async fn create_or_update_player(player: NewPlayer) -> StoreResult<i32> {
    query_with_arguments(
    get_store(),
    "INSERT INTO players(account_id, username, country_code) VALUES (?, ?, ?) ON CONFLICT(account_id) DO UPDATE SET username=excluded.username, country_code=excluded.country_code RETURNING uid",
    |query| {
        query.bind(player.account_id)
        .bind(player.username)
        .bind(player.country_code.unwrap_or("WOR".to_string()))
    }).await.map(|row| row.get(0))
}

pub async fn get_player_profile(uid: i32) -> StoreResult<PlayerProfile> {
    query_with_arguments(get_store(),
    "SELECT username, account_id, created_at, last_played_at, country_code, title, games_played, games_won FROM player_summary WHERE uid = ?", 
    |query| query.bind(uid))
    .await
    .map(|row| PlayerProfile { uid, name: row.get(0) , account_id: row.get(1), created_at: row.get(2), last_played_at: row.get::<Option<DateTime<Utc>>, usize>(3).unwrap_or_default(), country_code: row.get(4), title: row.get(5), games_played: row.get(6), games_won: row.get(7) })
}
