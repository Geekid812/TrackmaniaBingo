use tracing::debug;
use warp::http::StatusCode;
use warp::Reply;

use crate::core::directory;

pub fn close_room(join_code: String) {
    debug!("deleting room {}", join_code);
    directory::ROOMS.remove(join_code);
}

pub fn redirect_roomlist(reply: impl Reply) -> impl Reply {
    warp::reply::with_header(
        warp::reply::with_status(reply, StatusCode::FOUND),
        "location",
        "/roomlist",
    )
}
