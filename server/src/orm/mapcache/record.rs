use super::schema::maps;
use crate::core::util::serialize::serialize_time;
use chrono::NaiveDateTime;
use diesel::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Queryable, Selectable, Identifiable, Serialize, Deserialize, Clone, Debug)]
#[diesel(table_name = maps)]
#[diesel(primary_key(tmxid))]
#[serde(rename_all(deserialize = "PascalCase"))]
pub struct MapRecord {
    #[serde(rename(deserialize = "TrackID"))]
    pub tmxid: i32,
    #[serde(rename(deserialize = "TrackUID"))]
    pub uid: String,
    #[serde(rename(deserialize = "UserID"))]
    pub userid: i32,
    pub author_login: String,
    pub username: String,
    #[serde(rename(deserialize = "Name"))]
    pub track_name: String,
    #[serde(rename(deserialize = "GbxMapName"))]
    pub gbx_name: String,
    #[serde(rename(deserialize = "DisplayCost"))]
    pub coppers: i32,
    pub author_time: i32,
    #[serde(serialize_with = "serialize_time")]
    pub uploaded_at: NaiveDateTime,
    #[serde(serialize_with = "serialize_time")]
    pub updated_at: NaiveDateTime,
    pub tags: Option<String>,
    #[serde(rename(deserialize = "StyleName"))]
    pub style: Option<String>,
}
