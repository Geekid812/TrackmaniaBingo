use bytes::BytesMut;
use serde::Serialize;
use serde_json::from_str;
use serde_repr::Serialize_repr;
use tracing::{info, warn};

use super::client::NetClient;
use super::version::Version;
use crate::datatypes::HandshakeRequest;
use crate::{config, store};

/// Message handler for an unauthenticated client. Main logic of the connection handshake.
pub async fn handshake_message_received(client: &mut NetClient, message: BytesMut) {
    let required_version: Version = get_required_version_config();

    let message = match String::from_utf8(message.to_vec()) {
        Ok(str) => str,
        Err(e) => {
            handshake_rejection(client, format!("could not decode utf-8 message: {}", e));
            return;
        }
    };

    let handshake: HandshakeRequest = match from_str(&message) {
        Ok(req) => req,
        Err(e) => {
            handshake_rejection(client, format!("could not parse handshake request: {}", e));
            return;
        }
    };

    let Ok(client_version) = Version::try_from(handshake.version.clone()) else {
        handshake_rejection(client, "could not parse version string".into());
        return;
    };

    // Client version check
    if client_version < required_version {
        handshake_rejection(
            client,
            format!(
                "out of date: minimum plugin version is {}, you have {}",
                required_version, client_version
            ),
        );
        return;
    }

    // Match token to a valid user in storage
    let player_record = store::player::get_player_from_token(&handshake.token).await;

    let player = match player_record {
        Ok(player) => player,
        Err(sqlx::Error::RowNotFound) => {
            handshake_rejection(client, format!("authentication token rejected"));
            return;
        }
        Err(e) => {
            handshake_rejection(client, format!("store error: {}", e));
            return;
        }
    };

    handshake_success(
        client,
        HandshakeSuccess {
            uid: player.uid,
            display_name: player.display_name,
            can_reconnect: false,
        },
    );
    // TODO: handshake completed, stop listening and switch handlers
}

/// Send a rejection message with the provided reason message.
fn handshake_rejection(client: &NetClient, reason: String) {
    warn!(cid = client.cid(), "rejected: {}", reason);
    client.messager().send(&HandshakeResponse::failure(reason));
}

/// Send a success message for completing the handshake.
fn handshake_success(client: &NetClient, data: HandshakeSuccess) {
    info!(
        cid = client.cid(),
        "authenticated: {} (uid {})", data.display_name, data.uid
    );
    client.messager().send(&HandshakeResponse::success(data));
}

/// Get the client minimum version from the configuration.
fn get_required_version_config() -> Version {
    config::get_string("client.required_version")
        .expect("configuration key client.required_version not specified")
        .try_into()
        .expect("invalid value for client.required_version")
}

#[derive(Serialize)]
struct HandshakeResponse {
    success: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    reason: Option<String>,
    #[serde(flatten, skip_serializing_if = "Option::is_none")]
    data: Option<HandshakeSuccess>,
}

impl HandshakeResponse {
    fn failure(reason: String) -> Self {
        Self {
            success: false,
            reason: Some(reason),
            data: None,
        }
    }

    fn success(data: HandshakeSuccess) -> Self {
        Self {
            success: true,
            reason: None,
            data: Some(data),
        }
    }
}

#[derive(Serialize)]
pub struct HandshakeSuccess {
    pub uid: u32,
    pub display_name: String,
    pub can_reconnect: bool,
}

#[derive(Serialize_repr, PartialEq, Eq)]
#[repr(i32)]
pub enum HandshakeCode {
    Ok = 0,
    ParseError = 1,
    IncompatibleVersion = 2,
    AuthFailure = 3,
    AuthRefused = 4,
    ReadError = 5,
    InvalidVersion = 6,
    NoUsername = 7,
}
