use std::collections::HashMap;

use serde::{Deserialize, Serialize};
use sqlx::Row;

use crate::orm::Connection;

#[derive(Serialize, Deserialize, Clone, Debug, Default)]
pub struct DailyChallengeResult {
    pub player_count: i32,
    pub winners: Vec<PlayerRef>,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct PlayerRef {
    pub name: String,
    pub uid: i32,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct DailyResults {
    pub results: HashMap<String, DailyChallengeResult>,
}

pub async fn get_daily_results(
    conn: &mut Connection,
    period: &str,
) -> Result<DailyResults, sqlx::Error> {
    let mut results = HashMap::new();
    sqlx::query("SELECT matches.daily_timedate, players.username, player_uid, outcome FROM matches_players JOIN matches ON matches.uid=matches_players.match_uid JOIN players ON players.uid=matches_players.player_uid WHERE daily_timedate LIKE ?;")
        .bind(period)
        .fetch_all(&mut **conn)
        .await?
        .into_iter()
        .for_each(|row| {
            let result = results.entry(row.get("daily_timedate")).or_insert(DailyChallengeResult::default());
            result.player_count += 1;
            if row.get::<String, _>("outcome") == "W" {
                result.winners.push(PlayerRef { name: row.get("username"), uid: row.get("player_uid") });
            }
        });
    Ok(DailyResults { results })
}
