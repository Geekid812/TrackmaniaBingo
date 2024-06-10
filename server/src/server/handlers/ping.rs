use serde::Deserialize;

use crate::server::context::PlayerContext;

use super::{generic, Request, Response};

#[derive(Deserialize, Debug)]
pub struct Ping;

#[typetag::deserialize]
impl Request for Ping {
    fn handle(&self, _ctx: &mut PlayerContext) -> Box<dyn Response> {
        Box::new(generic::Ok)
    }
}
