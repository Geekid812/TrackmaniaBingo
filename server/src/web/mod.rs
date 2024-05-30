use std::convert::Infallible;

use warp::{fs, get, path, Filter, Rejection};

use crate::{config, CONFIG};

use self::routes::auth;

mod actions;
mod reject;
mod roomlist;
mod routes;

pub async fn main() {
    let index = get().and(path::end()).map(|| "TODO: Index");

    let routes = index.or(auth::get_routes());
    warp::serve(routes)
        .run((
            [127, 0, 0, 1],
            config::get_integer("network.http_port").expect("key network.http_port not set") as u16,
        ))
        .await;
}
