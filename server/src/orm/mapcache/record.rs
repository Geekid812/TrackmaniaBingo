use super::schema::maps;
use crate::core::util::serialize::serialize_time;
use chrono::NaiveDateTime;
use diesel::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Queryable, Selectable, Identifiable, Serialize, Deserialize, Clone, Debug)]
#[diesel(table_name = maps)]
#[diesel(primary_key(tmxid))]
pub struct MapRecord {
    pub tmxid: i32,
    pub uid: Option<String>,
    pub userid: i32,
    pub author_login: String,
    pub username: String,
    pub track_name: String,
    pub gbx_name: String,
    pub coppers: i32,
    pub author_time: i32,
    #[serde(serialize_with = "serialize_time")]
    pub uploaded_at: NaiveDateTime,
    #[serde(serialize_with = "serialize_time")]
    pub updated_at: NaiveDateTime,
    pub tags: Option<String>,
    pub style: Option<String>,
}
