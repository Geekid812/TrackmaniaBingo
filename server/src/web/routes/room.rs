use chrono::{DateTime, Utc};
use reqwest::StatusCode;
use serde::{Deserialize, Serialize};
use warp::filters::method::get;
use warp::reply::{with_status};
use warp::Filter;
use warp::{Rejection, Reply};

use crate::core::directory::ROOMS;
use crate::core::models::room::RoomState;
use crate::core::room::GameRoom;

pub fn get_routes() -> impl Filter<Extract = (impl Reply,), Error = Rejection> + Clone {
    let index = get()
        .and(warp::path::param())
        .and(warp::path::end())
        .map(get_room);
    warp::path("room").and(index)
}

#[derive(Serialize, Deserialize, Debug)]
pub struct NetworkRoomDetail {
    #[serde(flatten)]
    state: RoomState,
    created_at: DateTime<Utc>,
    host_name: Option<String>,
}

impl From<&GameRoom> for NetworkRoomDetail {
    fn from(value: &GameRoom) -> Self {
        Self {
            state: value.get_state(),
            created_at: value.created().clone(),
            host_name: value.host_name(),
        }
    }
}

/// Listing for all currently open rooms.
fn get_room(joincode: String) -> impl warp::Reply {
    let room_opt = ROOMS.find(joincode);
    let response = if let Some(room) = room_opt {
        Some(NetworkRoomDetail::from(&*room.lock()))
    } else {
        None
    };

    with_status(
        warp::reply::json(&response),
        response
            .map(|_| StatusCode::OK)
            .unwrap_or(StatusCode::NOT_FOUND),
    )
}
