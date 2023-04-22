use std::convert::Infallible;

use handlebars::Handlebars;
use once_cell::sync::Lazy;
use serde::Serialize;
use serde_json::json;
use warp::{Filter, Rejection};

use crate::config;

mod actions;
mod helpers;
mod reject;
mod roomlist;

static HANDLEBARS: Lazy<Handlebars<'static>> = Lazy::new(load_handlebars);

pub async fn main() {
    let serve_static = warp::path("static").and(warp::fs::dir("src/web/static"));
    let index = warp::get()
        .and(warp::path::end())
        .map(|| render("index", json!({"the_val": 42})));

    let roomlist = warp::get()
        .and(warp::path("roomlist"))
        .and(warp::path::end())
        .map(|| render("roomlist", roomlist::get_template_data()));

    let delete_room = warp::path!("room" / String / "delete")
        .map(actions::close_room)
        .untuple_one()
        .map(warp::reply)
        .map(actions::redirect_roomlist);

    let protected = index.or(roomlist).or(delete_room);
    let routes = serve_static.or(authenticate().and(protected));
    warp::serve(routes).run(([127, 0, 0, 1], 8080)).await;
}

fn load_handlebars() -> Handlebars<'static> {
    let mut hbs = Handlebars::new();
    #[cfg(debug_assertions)]
    hbs.set_dev_mode(true);

    hbs.register_helper("strftime", Box::new(helpers::strftime));
    hbs.register_template_file("index", "src/web/templates/index.hbs")
        .expect("handlebars template load failed");
    hbs.register_template_file("roomlist", "src/web/templates/roomlist.hbs")
        .expect("handlebars template load failed");
    hbs
}

fn render<T: Serialize>(template: &str, value: T) -> impl warp::Reply {
    let rendered = HANDLEBARS
        .render(template, &value)
        .unwrap_or_else(|err| err.to_string());
    warp::reply::html(rendered)
}

fn authenticate() -> impl Filter<Extract = (), Error = Rejection> + Copy {
    warp::cookie("key")
        .or_else(|_| async { Ok::<(String,), Infallible>((String::new(),)) })
        .and_then(|key: String| async move {
            if config::ADMIN_KEY.is_none() || key == config::ADMIN_KEY.unwrap() {
                Ok(())
            } else {
                Err(warp::reject::custom(reject::Forbidden))
            }
        })
        .untuple_one()
}
