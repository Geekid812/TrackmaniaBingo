use std::sync::Arc;

use serde::{Deserialize, Serialize};
use serde_json::{from_str, to_string};
use serde_repr::Serialize_repr;
use tokio::sync::mpsc::error::SendError;

use crate::{
    config,
    rest::auth::{Authenticator, PlayerIdentity, ValidationError},
    socket::{SocketAction, SocketReader, SocketWriter},
    util::version::Version,
};

pub async fn read_handshake(
    reader: &mut SocketReader,
    auth: Arc<Authenticator>,
) -> Result<PlayerIdentity, HandshakeCode> {
    let handshake = match SocketReader::recv(reader).await {
        Some(msg) => {
            from_str::<'_, HandshakeRequest>(&msg).map_err(|_| HandshakeCode::ParseError)?
        }
        None => {
            // Connection closed
            return Err(HandshakeCode::ReadError);
        }
    };

    let client_version =
        Version::try_from(handshake.version).map_err(|_| HandshakeCode::InvalidVersion)?;

    // Client version check
    if client_version < config::MINIMUM_CLIENT_VERSION {
        return Err(HandshakeCode::IncompatibleVersion);
    }

    if config::AUTHENTICATION_API_SECRET.is_none() {
        // Auth disabled
        return Ok(PlayerIdentity {
            account_id: handshake.username.clone(),
            display_name: handshake.username,
        });
    }

    // Authentification
    let validation_result = auth.validate(handshake.token).await;
    let identity = match validation_result {
        Ok(i) => i,
        Err(e) => {
            return Err(match e {
                ValidationError::BackendError(_) => HandshakeCode::AuthRefused,
                ValidationError::RequestError(_) => HandshakeCode::AuthFailure,
            })
        }
    };

    return Ok(identity);
}

pub fn deny_socket(
    writer: &SocketWriter,
    code: HandshakeCode,
) -> Result<(), SendError<SocketAction>> {
    writer.send(SocketAction::Message(
        to_string(&HandshakeResponse { code, data: None }).expect("serializing handshake failed"),
    ))?;
    writer.send(SocketAction::Stop)
}

pub fn accept_socket(
    writer: &SocketWriter,
    data: HandshakeSuccess,
) -> Result<(), SendError<SocketAction>> {
    writer.send(SocketAction::Message(
        to_string(&HandshakeResponse {
            code: HandshakeCode::Ok,
            data: Some(data),
        })
        .expect("serializing handshake failed"),
    ))
}

#[derive(Deserialize)]
struct HandshakeRequest {
    version: String,
    token: String,
    username: String,
}

#[derive(Serialize)]
struct HandshakeResponse {
    code: HandshakeCode,
    #[serde(flatten, skip_serializing_if = "Option::is_none")]
    data: Option<HandshakeSuccess>,
}

#[derive(Serialize)]
pub struct HandshakeSuccess {
    pub username: String,
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
}
