use warp::{get, path, Filter};

use crate::config;

use self::routes::auth;

mod actions;
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
