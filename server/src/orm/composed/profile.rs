use diesel::{BelongingToDsl, QueryDsl, RunQueryDsl, SqliteConnection};
use serde::Serialize;

use crate::orm::{
    models::{matches::PlayerToMatch, player::Player},
    schema::matches_players,
};

#[derive(Serialize)]
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

impl From<Option<String>> for MatchOutcome {
    fn from(value: Option<String>) -> Self {
        match value.as_deref() {
            Some("W") => MatchOutcome::Win,
            Some("L") => MatchOutcome::Loss,
            _ => MatchOutcome::Unknown,
        }
    }
}

pub fn get_profile(
    conn: &mut SqliteConnection,
    player: Player,
) -> diesel::QueryResult<PlayerProfile> {
    let matches = PlayerToMatch::belonging_to(&player)
        .select(matches_players::outcome)
        .load::<Option<String>>(conn)?
        .into_iter()
        .map(MatchOutcome::from)
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
