use warp::{get, path, Filter};

use crate::config;

use self::routes::auth;

mod actions;
mod roomlist;
mod routes;

pub async fn main() {
    let index = get().and(path::end()).map(|| "Index page: Hello!");

    let routes = index.or(auth::get_routes());
    warp::serve(routes)
        .run((
            if config::is_development() {
                [127, 0, 0, 1]
            } else {
                [0, 0, 0, 0]
            },
            config::get_integer("network.http_port").expect("key network.http_port not set") as u16,
        ))
        .await;
}
