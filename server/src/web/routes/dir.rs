
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use warp::filters::method::get;
use warp::Filter;
use warp::{Rejection, Reply};

use crate::core::directory::{MATCHES, ROOMS};
use crate::core::livegame::LiveMatch;
use crate::core::models::livegame::MatchState;
use crate::core::models::room::RoomState;
use crate::core::room::GameRoom;

use super::room::NetworkRoomDetail;

pub fn get_routes() -> impl Filter<Extract = (impl Reply,), Error = Rejection> + Clone {
    let rooms = get().and(warp::path("rooms")).then(get_rooms);
    let live_games = get().and(warp::path("matches")).then(get_livegames);
    warp::path("dir").and(rooms.or(live_games))
}

#[derive(Serialize, Deserialize, Debug)]
pub struct NetworkLiveMatchDetail {
    #[serde(flatten)]
    state: MatchState,
}

impl From<&LiveMatch> for NetworkLiveMatchDetail {
    fn from(value: &LiveMatch) -> Self {
        Self {
            state: value.get_state(),
        }
    }
}

/// Listing for all currently open rooms.
async fn get_rooms() -> impl warp::Reply {
    let room_directory = ROOMS.lock();
    let game_rooms: Vec<NetworkRoomDetail> = room_directory
        .values()
        .map(|room_ref| NetworkRoomDetail::from(&*room_ref.lock()))
        .collect();
    warp::reply::json(&game_rooms)
}

/// Listing for all currently running game matches.
async fn get_livegames() -> impl warp::Reply {
    let match_directory = MATCHES.lock();
    let live_games: Vec<NetworkLiveMatchDetail> = match_directory
        .values()
        .map(|room_ref| NetworkLiveMatchDetail::from(&*room_ref.lock()))
        .collect();
    warp::reply::json(&live_games)
}
