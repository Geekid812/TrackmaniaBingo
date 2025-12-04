use std::fmt::Debug;

use serde::Serialize;
use serde_json::{json, Value};
use thiserror::Error;

use ping::Ping;

use crate::server::{
    context::ClientContext,
    handlers::{
        activate_powerup::ActivatePowerup, change_player_team::ChangePlayerTeam,
        change_team::ChangeTeam, create_room::CreateRoom, create_team::CreateTeam,
        delete_team::DeleteTeam, edit_config::EditConfig, get_dice_choices::GetDiceChoices,
        get_public_rooms::GetPublicRooms, join_match::JoinMatch, join_room::JoinRoom,
        poll_vote::SubmitPollVote, reload_maps::ReloadMaps, send_chat::SendChatMessage,
        shuffle_teams::ShuffleTeams, start_match::StartMatch, submit_run::SubmitRun,
        unsubscribe_roomlist::UnsubscribeRoomlist, vote_reroll::CastRerollVote,
    },
};

mod activate_powerup;
mod change_player_team;
mod change_team;
mod create_room;
mod create_team;
mod delete_team;
mod edit_config;
mod get_dice_choices;
mod get_public_rooms;
mod join_match;
mod join_room;
mod ping;
mod poll_vote;
mod reload_maps;
mod send_chat;
mod shuffle_teams;
mod start_match;
mod submit_run;
mod unsubscribe_roomlist;
mod vote_reroll;

#[derive(Error, Debug)]
pub enum RequestError {
    #[error(transparent)]
    Parse(serde_json::Error),
    #[error("unknown request '{0}'")]
    NoMatchedHandler(String),
}

pub fn handle_request(
    ctx: &mut ClientContext,
    request: &str,
    args: Value,
) -> Result<Value, RequestError> {
    macro_rules! define_request_handler {
        ($t:ty, $f:path) => {
            if (request == stringify!($t)) {
                return Ok($f(
                    ctx,
                    serde_json::from_value::<$t>(args).map_err(RequestError::Parse)?,
                ));
            }
        };
    }

    define_request_handler!(Ping, ping::handle);
    define_request_handler!(CreateRoom, create_room::handle);
    define_request_handler!(CreateTeam, create_team::handle);
    define_request_handler!(DeleteTeam, delete_team::handle);
    define_request_handler!(ChangeTeam, change_team::handle);
    define_request_handler!(ChangePlayerTeam, change_player_team::handle);
    define_request_handler!(ShuffleTeams, shuffle_teams::handle);
    define_request_handler!(EditConfig, edit_config::handle);
    define_request_handler!(GetPublicRooms, get_public_rooms::handle);
    define_request_handler!(UnsubscribeRoomlist, unsubscribe_roomlist::handle);
    define_request_handler!(JoinRoom, join_room::handle);
    define_request_handler!(JoinMatch, join_match::handle);
    define_request_handler!(StartMatch, start_match::handle);
    define_request_handler!(ReloadMaps, reload_maps::handle);
    define_request_handler!(SendChatMessage, send_chat::handle);
    define_request_handler!(SubmitRun, submit_run::handle);
    define_request_handler!(CastRerollVote, vote_reroll::handle);
    define_request_handler!(SubmitPollVote, poll_vote::handle);
    define_request_handler!(ActivatePowerup, activate_powerup::handle);
    define_request_handler!(GetDiceChoices, get_dice_choices::handle);

    Err(RequestError::NoMatchedHandler(request.to_string()))
}

/// Return an empty OK response.
pub fn ok() -> Value {
    Value::Null
}

/// Return a serialized response.
pub fn response<T: Serialize>(response: T) -> Value {
    serde_json::to_value(response).expect("response serialization failure")
}

/// Return a basic string error.
pub fn error(message: &str) -> Value {
    json!({
        "error": message,
    })
}
