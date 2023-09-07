use crate::{
    core::util::serialize::{serialize_or_default, serialize_time},
    orm::Connection,
};
use chrono::NaiveDateTime;
use serde::{Deserialize, Serialize};
use sqlx::{query_builder::Separated, FromRow, Sqlite};

#[derive(Serialize, Deserialize, Clone, Debug, FromRow)]
pub struct Player {
    pub uid: i32,
    pub account_id: String,
    pub username: String,
    #[serde(serialize_with = "serialize_time")]
    pub created_at: NaiveDateTime,
    pub score: i32,
    pub deviation: i32,
    pub country_code: String,
    #[allow(unused)]
    #[serde(skip_serializing)]
    client_token: Option<String>,
    #[serde(serialize_with = "serialize_or_default")]
    pub title: Option<String>,
}

impl Player {
    pub fn bind_values(&self, values: &mut Separated<'_, '_, Sqlite, &'static str>) {
        values
            .push_bind(self.uid)
            .push_bind(self.account_id.clone())
            .push_bind(self.username.clone())
            .push_bind(self.created_at)
            .push_bind(self.score)
            .push_bind(self.deviation)
            .push_bind(self.country_code.clone())
            .push_bind(self.client_token.clone())
            .push_bind(self.title.clone());
    }
}

pub async fn get(mut db: Connection, uid: i32) -> Result<Option<Player>, sqlx::Error> {
    let res = sqlx::query("SELECT * FROM players WHERE uid = ?")
        .bind(uid)
        .fetch_one(db.as_mut())
        .await
        .map(|row| Some(Player::from_row(&row).expect("Player from_row failed")));

    match res.as_ref().err() {
        Some(sqlx::Error::RowNotFound) => Ok(None),
        _ => res,
    }
}

#[derive(Debug)]
pub struct NewPlayer {
    pub account_id: String,
    pub username: String,
    pub client_token: String,
    pub country_code: Option<String>,
}

impl NewPlayer {
    pub fn bind_values(&self, values: &mut Separated<'_, '_, Sqlite, &'static str>) {
        values
            .push_bind(self.account_id.clone())
            .push_bind(self.username.clone())
            .push_bind(self.client_token.clone())
            .push_bind(self.country_code.clone());
    }
}
