use chrono::{DateTime, Utc};

/// Model of a livegame match.
#[derive(Debug)]
pub struct Match {
    pub uid: String,
    pub started_at: DateTime<Utc>,
    pub ended_at: DateTime<Utc>,
}

/// The outcome of a match for a single player.
#[derive(Debug)]
pub enum MatchOutcome {
    Win,
    Draw,
    Loss,
}

impl MatchOutcome {
    /// Returns the string code of the enum in the database.
    pub fn as_dbcode(&self) -> &'static str {
        match self {
            MatchOutcome::Win => "W",
            MatchOutcome::Draw => "D",
            MatchOutcome::Loss => "L",
        }
    }
}

/// Model of the results of a Bingo match.
#[derive(Debug)]
pub struct MatchResult(pub Vec<(i32, MatchOutcome)>);
