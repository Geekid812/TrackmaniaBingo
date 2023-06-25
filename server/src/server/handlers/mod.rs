use std::fmt::Debug;

use crate::server::context::ClientContext;

mod change_team;
mod create_room;
mod edit_config;
mod generic;
mod get_public_rooms;
mod join_room;
mod ping;
mod start_match;
mod submit_run;
mod unsubscribe_roomlist;

#[typetag::deserialize(tag = "req")]
pub trait Request: Debug {
    fn handle(&self, ctx: &mut ClientContext) -> Box<dyn Response>;
}

#[typetag::serialize(tag = "res")]
pub trait Response: Debug {}
