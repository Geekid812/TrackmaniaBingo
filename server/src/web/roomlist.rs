use chrono::{DateTime, Utc};
use serde::Serialize;

use crate::{
    gameroom::{GameRoom, RoomConfiguration},
    roomlist,
};

#[derive(Serialize, Debug)]
pub struct RoomListTemplate {
    rooms: Vec<TemplateRoom>,
    public: i32,
    private: i32,
}

#[derive(Serialize, Debug)]
pub struct TemplateRoom {
    name: String,
    join_code: String,
    host: Option<String>,
    config: RoomConfiguration,
    player_count: usize,
    created: DateTime<Utc>,
}

impl From<&GameRoom> for TemplateRoom {
    fn from(value: &GameRoom) -> Self {
        Self {
            name: value.name().to_owned(),
            join_code: value.join_code().to_owned(),
            host: value.host_name(),
            config: value.config().clone(),
            player_count: value.players().len(),
            created: value.created().clone(),
        }
    }
}

pub fn get_template_data() -> RoomListTemplate {
    let rooms: Vec<TemplateRoom> = roomlist::lock()
        .iter()
        .map(|(_, room)| TemplateRoom::from(&*room.lock()))
        .collect();
    let (public, private) = rooms.iter().fold((0, 0), |(pub_, priv_), x| {
        if x.config.public {
            (pub_ + 1, priv_)
        } else {
            (pub_, priv_ + 1)
        }
    });
    RoomListTemplate {
        rooms,
        public,
        private,
    }
}
