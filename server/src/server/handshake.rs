use bytes::BytesMut;
use serde::Serialize;
use serde_json::from_str;
use tracing::{debug, info, warn};

use super::auth::login;
use super::client::{ClientCallbackImplementation, NetClient};
use super::context::ClientContext;
use super::token::get_player_from_token;
use super::version::Version;
use crate::datatypes::{HandshakeFailureIntentCode, HandshakeRequest, KeyExchangeRequest, PlayerProfile};
use crate::{config, store};

/// Message handler for an unauthenticated client. Main logic of the connection handshake.
pub async fn handshake_message_received(client: &mut NetClient, message: BytesMut) {
    let required_version: Version = get_required_version_config();

    let message = match String::from_utf8(message.to_vec()) {
        Ok(str) => str,
        Err(e) => {
            handshake_rejection(
                client,
                format!("could not decode utf-8 message: {}", e),
                HandshakeFailureIntentCode::ShowError,
            );
            return;
        }
    };

    // if we requested to exchange keys, process the request
    match from_str::<KeyExchangeRequest>(&message) {
        Ok(req) => {
            debug!("{:?}", req);
            match login(req).await {
                Ok(token) => {
                    let _ = client.messager().send(&TokenHint { token });
                },
                Err(e) => {
                    handshake_rejection(
                        client,
                        format!("failed to login: {}", e),
                        HandshakeFailureIntentCode::ShowError,
                    );
                }
            }
            return;
        },
        _ => ()
    }

    let handshake: HandshakeRequest = match from_str(&message) {
        Ok(req) => req,
        Err(e) => {
            handshake_rejection(
                client,
                format!("could not parse handshake request: {}", e),
                HandshakeFailureIntentCode::ShowError,
            );
            return;
        }
    };

    let Ok(client_version) = Version::try_from(handshake.version.clone()) else {
        handshake_rejection(
            client,
            "could not parse version string".into(),
            HandshakeFailureIntentCode::ShowError,
        );
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
            HandshakeFailureIntentCode::RequireUpdate,
        );
        return;
    }

    // Match token to a valid user in memory
    let player_record = get_player_from_token(&handshake.token);

    let player_uid = match player_record {
        Some(uid) => uid,
        None => {
            handshake_rejection(
                client,
                format!("authentication token rejected"),
                HandshakeFailureIntentCode::Reauthenticate,
            );
            return;
        }
    };

    // Load that player's profile
    let profile = match store::player::get_player_profile(player_uid).await {
        Ok(profile) => profile,
        Err(e) => {
            handshake_rejection(
                client,
                format!("store error: {}", e),
                HandshakeFailureIntentCode::ShowError,
            );
            return;
        }
    };

    handshake_success(
        client,
        HandshakeSuccess {
            profile: profile.clone(),
            can_reconnect: false,
        },
    );

    // handshake completed, stop listening and switch to the mainloop
    client.set_context(Some(ClientContext::new(profile, client.messager())));
    client.set_callback_mode(ClientCallbackImplementation::Mainloop);
}

/// Send a rejection message with the provided reason message.
fn handshake_rejection(client: &NetClient, reason: String, code: HandshakeFailureIntentCode) {
    warn!(cid = client.cid(), "rejected: {}", reason);
    let _ = client
        .messager()
        .send(&HandshakeResponse::failure(reason, code));
}

/// Send a success message for completing the handshake.
fn handshake_success(client: &NetClient, data: HandshakeSuccess) {
    info!(
        cid = client.cid(),
        "authenticated: {} (uid {})", data.profile.name, data.profile.uid
    );
    let _ = client.messager().send(&HandshakeResponse::success(data));
}

/// Get the client minimum version from the configuration.
fn get_required_version_config() -> Version {
    config::get_string("client.required_version")
        .expect("configuration key client.required_version not specified")
        .try_into()
        .expect("invalid value for client.required_version")
}

#[derive(Serialize)]
struct TokenHint {
    pub token: String
}

#[derive(Serialize)]
struct HandshakeResponse {
    success: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    reason: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    intent_code: Option<HandshakeFailureIntentCode>,
    #[serde(flatten, skip_serializing_if = "Option::is_none")]
    data: Option<HandshakeSuccess>,
}

impl HandshakeResponse {
    fn failure(reason: String, code: HandshakeFailureIntentCode) -> Self {
        Self {
            success: false,
            reason: Some(reason),
            intent_code: Some(code),
            data: None,
        }
    }

    fn success(data: HandshakeSuccess) -> Self {
        Self {
            success: true,
            reason: None,
            intent_code: None,
            data: Some(data),
        }
    }
}

#[derive(Serialize)]
pub struct HandshakeSuccess {
    pub profile: PlayerProfile,
    pub can_reconnect: bool,
}
