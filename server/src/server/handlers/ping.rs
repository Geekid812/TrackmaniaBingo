use serde::Deserialize;
use serde_json::Value;

use crate::server::{context::ClientContext, handlers::ok};

#[derive(Deserialize, Debug)]
pub struct Ping {}

pub fn handle(_ctx: &mut ClientContext, _args: Ping) -> Value {
    ok()
}
