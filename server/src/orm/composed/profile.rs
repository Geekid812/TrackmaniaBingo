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
    pub daily_count: i32,
    pub daily_wins: i32,
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
    let matches = sqlx::query("SELECT outcome, matches.daily_timedate FROM matches_players JOIN matches ON matches.uid=matches_players.match_uid WHERE player_uid = ?")
        .bind(player.uid)
        .fetch_all(&mut **conn)
        .await?
        .into_iter()
        .map(|row| (MatchOutcome::from_value(row.get("outcome")), row.get::<Option<String>, _>("daily_timedate").is_some()))
        .collect::<Vec<(MatchOutcome, bool)>>();
    let (match_count, daily_count) = matches.iter().fold((0, 0), |mut v, o| {
        if o.1 {
            v.1 += 1;
        } else {
            v.0 += 1;
        }
        v
    });
    let (wins, daily_wins) =
        matches
            .iter()
            .filter(|o| (*o).0 == MatchOutcome::Win)
            .fold((0, 0), |mut v, o| {
                if o.1 {
                    v.1 += 1;
                } else {
                    v.0 += 1;
                }
                v
            });
    let losses = matches
        .iter()
        .filter(|o| (*o).0 == MatchOutcome::Loss && !o.1)
        .count() as i32;
    Ok(PlayerProfile {
        player,
        match_count,
        wins,
        losses,
        daily_count,
        daily_wins,
    })
}
