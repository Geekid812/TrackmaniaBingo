use tracing::debug;
use warp::http::StatusCode;
use warp::Reply;

use crate::roomlist;

pub fn close_room(join_code: String) {
    debug!("deleting room {}", join_code);
    roomlist::remove_code(join_code);
}

pub fn redirect_roomlist(reply: impl Reply) -> impl Reply {
    warp::reply::with_header(
        warp::reply::with_status(reply, StatusCode::FOUND),
        "location",
        "/roomlist",
    )
}
