use crate::core::util::serialize::serialize_time;
use chrono::NaiveDateTime;
use serde::Serialize;
use sqlx::FromRow;

#[derive(Serialize, Clone, Debug, FromRow)]
pub struct MapRecord {
    pub tmxid: i32,
    pub uid: String,
    pub webservices_id: Option<String>,
    pub userid: i32,
    pub username: String,
    pub track_name: String,
    pub gbx_name: String,
    #[sqlx(default)]
    pub wr_time: Option<i32>,
    pub author_time: i32,
    pub gold_time: i32,
    pub silver_time: i32,
    pub bronze_time: i32,
    #[serde(serialize_with = "serialize_time")]
    pub uploaded_at: NaiveDateTime,
    #[serde(serialize_with = "serialize_time")]
    pub updated_at: NaiveDateTime,
    pub tags: String,
    pub style: Option<String>,
}
