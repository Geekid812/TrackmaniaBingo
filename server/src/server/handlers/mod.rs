use std::fmt::Debug;

use bytes::BytesMut;
use tracing::{debug, warn};

use crate::server::context::PlayerContext;

use super::{
    client::NetClient,
    requests::{BaseRequest, BaseResponse},
};

// All request implementations
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
mod send_chat;
mod start_match;
mod submit_run;
mod unsubscribe_roomlist;
mod vote_reroll;

/// Message handler for an authenticated client. Main logic of the connection loop.
pub async fn mainloop_message_received(client: &mut NetClient, message: BytesMut) {
    let response: BaseResponse = match String::from_utf8(message.to_vec()) {
        Ok(string) => {
            // Match a request
            match serde_json::from_str::<BaseRequest>(&string) {
                Ok(incoming) => {
                    let response = incoming.request.handle(ctx);
                    incoming.build_reply(response)
                }
                Err(e) => {
                    let error = format!("unknown message received: {e}");
                    warn!(error);
                    BaseResponse::bare(Box::new(generic::Error::new(error)))
                }
            }
        }
        Err(e) => BaseResponse::bare(Box::new(generic::Error::new(format!(
            "could not parse utf-8: {}",
            e
        )))),
    };
    let sent = client.messager().send(&response);
}

/// Generic request trait. A request handler implements this trait,
/// the request body must match the content of the structure.
#[typetag::deserialize(tag = "req")]
pub(super) trait Request: Debug {
    fn handle(&self, ctx: &mut PlayerContext) -> Box<dyn Response>;
}

/// Generic response trait. It can be any type that can be serialized.
#[typetag::serialize(tag = "res")]
pub(super) trait Response: Debug {}
