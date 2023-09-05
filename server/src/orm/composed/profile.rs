use serde::{Deserialize, Serialize};
use sqlx::Row;

use crate::orm::{models::player::Player, Connection};

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct PlayerProfile {
    #[serde(flatten)]
    pub player: Player,
    pub match_count: i32,
    pub wins: i32,
    pub losses: i32,
}

#[derive(PartialEq, Eq, Debug)]
enum MatchOutcome {
    Unknown,
    Win,
    Loss,
}

impl MatchOutcome {
    fn from_value(value: Option<String>) -> Self {
        match value.as_deref() {
            Some("W") => MatchOutcome::Win,
            Some("L") => MatchOutcome::Loss,
            _ => MatchOutcome::Unknown,
        }
    }
}

pub async fn get_profile(
    conn: &mut Connection,
    player: Player,
) -> Result<PlayerProfile, sqlx::Error> {
    let matches = sqlx::query("SELECT outcome FROM matches_players WHERE player_uid = ?")
        .bind(player.uid)
        .fetch_all(&mut **conn)
        .await?
        .into_iter()
        .map(|row| row.get("outcome"))
        .map(MatchOutcome::from_value)
        .collect::<Vec<MatchOutcome>>();
    let wins = matches.iter().filter(|o| **o == MatchOutcome::Win).count() as i32;
    let losses = matches.iter().filter(|o| **o == MatchOutcome::Loss).count() as i32;
    Ok(PlayerProfile {
        player,
        match_count: matches.len() as i32,
        wins,
        losses,
    })
}
