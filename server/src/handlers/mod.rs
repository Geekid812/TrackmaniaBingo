use std::fmt::Debug;

use crate::context::ClientContext;

mod change_team;
mod create_room;
mod generic;
mod ping;

#[typetag::deserialize(tag = "req")]
pub trait Request: Debug {
    fn handle(&self, ctx: &mut ClientContext) -> Box<dyn Response>;
}

#[typetag::serialize(tag = "res")]
pub trait Response: Debug {}

#[typetag::deserialize(tag = "event")]
pub trait ClientEvent: Debug {
    fn handle(&self, ctx: &mut ClientContext);
}
