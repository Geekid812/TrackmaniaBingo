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
    pub name: String,
    pub gbx_map_name: String,
    pub authors: Vec<AuthorModel>,
    pub uploaded_at: NaiveDateTime,
    pub updated_at: NaiveDateTime,
    pub tags: Vec<TagModel>
}

#[derive(Deserialize)]
#[serde(rename_all = "PascalCase")]
pub struct TagModel {
    pub tag_id: i32,
    pub name: String,
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
