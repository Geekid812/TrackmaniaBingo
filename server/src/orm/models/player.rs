use crate::core::util::serialize::serialize_time;
use crate::orm::schema::players;
use chrono::NaiveDateTime;
use diesel::prelude::*;
use serde::Serialize;

#[derive(Queryable, Selectable, Identifiable, Serialize)]
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
    #[serde(skip_serializing)]
    client_token: Option<String>,
}
