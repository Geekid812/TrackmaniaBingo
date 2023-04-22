use serde::Deserialize;

use crate::context::ClientContext;

use super::{generic, Request, Response};

#[derive(Deserialize, Debug)]
pub struct Ping;

#[typetag::deserialize]
impl Request for Ping {
    fn handle(&self, _ctx: &mut ClientContext) -> Box<dyn Response> {
        Box::new(generic::Ok)
    }
}
