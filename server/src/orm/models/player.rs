use crate::orm::schema::players;
use chrono::{DateTime, Utc};
use diesel::prelude::*;

#[derive(Queryable, Selectable, Identifiable)]
#[diesel(table_name = players)]
#[diesel(primary_key(uid))]
pub struct Player {
    pub uid: u32,
    pub account_id: String,
    pub username: String,
    pub created_at: DateTime<Utc>,
    pub score: i32,
    pub deviation: i32,
    pub country_code: String,
    pub client_token: String,
}
