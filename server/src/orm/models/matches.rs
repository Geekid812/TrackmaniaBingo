use crate::core::util::serialize::serialize_time;
use chrono::NaiveDateTime;
use serde::Serialize;
use sqlx::{query_builder::Separated, FromRow, Sqlite};

#[derive(Serialize, FromRow, Debug)]
pub struct Match {
    pub uid: String,
    #[serde(serialize_with = "serialize_time")]
    pub started_at: NaiveDateTime,
    #[serde(serialize_with = "serialize_time")]
    pub ended_at: NaiveDateTime,
    pub daily_timedate: Option<String>,
}

impl Match {
    pub fn bind_values(&self, values: &mut Separated<'_, '_, Sqlite, &'static str>) {
        values
            .push_bind(self.uid.clone())
            .push_bind(self.started_at.clone())
            .push_bind(self.ended_at.clone())
            .push_bind(self.daily_timedate.clone());
    }
}

#[derive(Serialize, FromRow, Debug)]
pub struct PlayerToMatch {
    pub player_uid: i32,
    pub match_uid: String,
    pub outcome: String,
}

impl PlayerToMatch {
    pub fn bind_values(&self, values: &mut Separated<'_, '_, Sqlite, &'static str>) {
        values
            .push_bind(self.player_uid)
            .push_bind(self.match_uid.clone())
            .push_bind(self.outcome.clone());
    }
}
