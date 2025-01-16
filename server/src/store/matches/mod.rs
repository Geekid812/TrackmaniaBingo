mod models;

use super::{
    execute_with_arguments, get_store, query_with_arguments, StoreReadResult, StoreWriteResult,
};
pub use models::*;
use sqlx::Row;

// A limit on how many records can be inserted in a query before it should be split.
const MAX_RECORDS_PER_INSERT: usize = 100;

/// Create or update a match record.
pub async fn save_match_record(record: &Match) -> StoreWriteResult {
    execute_with_arguments(
    get_store(),
    "INSERT INTO matches(uid, started_at, ended_at) VALUES (?, ?, ?) ON CONFLICT(uid) DO UPDATE SET started_at=excluded.started_at, ended_at=excluded.ended_at",
    |query| {
        query.bind(&record.uid)
        .bind(record.started_at)
        .bind(record.ended_at)
    }).await.map(|_| ())
}

/// Find a match record from a match UID.
pub async fn get_match_record(uid: &str) -> StoreReadResult<Match> {
    query_with_arguments(
        get_store(),
        "SELECT uid, started_at, ended_at FROM matches WHERE uid = ?",
        |query| query.bind(uid),
    )
    .await
    .map(|row| Match {
        uid: row.get(0),
        started_at: row.get(1),
        ended_at: row.get(2),
    })
}

/// Create players' match outcome entries after a match has ended.
pub async fn create_match_result(match_uid: &str, result: MatchResult) -> StoreWriteResult {
    let chunks = result.0.chunks(MAX_RECORDS_PER_INSERT);
    for chunk in chunks {
        let query_arguments = &", (?, ?, ?)".repeat(chunk.len())[2..];
        let query = format!("INSERT INTO matches_players(player_uid, match_uid, outcome) VALUES {}", query_arguments);
        execute_with_arguments(get_store(), &query, |query| chunk.iter().fold(query, |query, r| {
            query.bind(r.0).bind(match_uid).bind(r.1.as_dbcode())
        })).await?;
    };

    Ok(())
}

/// Create an entry for a Bingo live match that has just ended.
pub async fn write_match_end(record: Match, result: MatchResult) -> StoreWriteResult {
    save_match_record(&record).await?;
    create_match_result(&record.uid, result).await?;
    Ok(())
}
