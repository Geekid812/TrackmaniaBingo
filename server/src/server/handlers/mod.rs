use std::fmt::Debug;

use crate::server::context::ClientContext;

mod change_team;
mod create_room;
mod create_team;
mod daily_challenge;
mod daily_results;
mod delete_team;
mod edit_config;
mod generic;
mod get_public_rooms;
mod join_room;
mod match_join;
mod ping;
mod ping_cell;
mod reload_maps;
mod start_match;
mod submit_run;
mod unsubscribe_roomlist;
mod vote_reroll;

#[typetag::deserialize(tag = "req")]
pub trait Request: Debug {
    fn handle(&self, ctx: &mut ClientContext) -> Box<dyn Response>;
}

#[typetag::serialize(tag = "res")]
pub trait Response: Debug {}
