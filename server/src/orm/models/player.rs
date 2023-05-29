use crate::core::util::serialize::{serialize_or_default, serialize_time};
use crate::orm::schema::players;
use chrono::NaiveDateTime;
use diesel::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Queryable, Selectable, Identifiable, Serialize, Deserialize, Clone, Debug)]
#[diesel(table_name = players)]
#[diesel(primary_key(uid))]
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

pub fn get(conn: &mut SqliteConnection, uid: i32) -> QueryResult<Player> {
    players::table.find(uid).first::<Player>(conn)
}
