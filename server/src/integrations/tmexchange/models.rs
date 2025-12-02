use chrono::NaiveDateTime;
use serde::Deserialize;

#[derive(Deserialize)]
#[serde(rename_all = "PascalCase")]
pub struct MapsResponse {
    pub more: bool,
    pub results: Vec<MapResponse>,
}

#[derive(Deserialize)]
#[serde(rename_all = "PascalCase")]
pub struct MapResponse {
    pub map_id: i32,
    pub map_uid: String,
    pub online_map_id: Option<String>,
    pub name: String,
    pub gbx_map_name: String,
    pub authors: Vec<AuthorModel>,
    pub uploaded_at: NaiveDateTime,
    pub updated_at: NaiveDateTime,
    pub medals: MedalModel,
    pub tags: Vec<TagModel>,
    #[serde(rename = "OnlineWR")]
    pub online_wr: Option<RecordModel>,
}

#[derive(Deserialize)]
#[serde(rename_all = "PascalCase")]
pub struct RecordModel {
    pub record_time: i32,
}

#[derive(Deserialize)]
#[serde(rename_all = "PascalCase")]
pub struct TagModel {
    pub tag_id: i32,
    pub name: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "PascalCase")]
pub struct MedalModel {
    pub author: i32,
    pub gold: i32,
    pub silver: i32,
    pub bronze: i32,
}

#[derive(Deserialize)]
#[serde(rename_all = "PascalCase")]
pub struct AuthorModel {
    pub user: UserModel,
    pub role: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "PascalCase")]
pub struct UserModel {
    pub name: String,
    pub user_id: i32,
}
