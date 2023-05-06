use serde::Serialize;

#[derive(Serialize, Clone, Debug)]
pub struct GameMap {
    pub track_id: i64,
    pub uid: String,
    pub name: String,
    pub author_name: String,
}
