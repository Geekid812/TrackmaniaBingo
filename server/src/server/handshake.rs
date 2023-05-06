use std::sync::Arc;
use std::time::Duration;

use futures::{select, FutureExt, StreamExt};
use serde::{Deserialize, Serialize};
use serde_json::from_str;
use serde_repr::Serialize_repr;
use tokio::time::sleep;
use tokio::{pin, sync::mpsc::error::SendError};

use super::version::Version;
use crate::transport::client::tcpnative::write;
use crate::{
    integrations::openplanet::{Authenticator, PlayerIdentity, ValidationError},
    transport::{client::tcpnative::TcpNativeClient, Tx},
    CONFIG,
};

pub async fn do_handshake(client: &mut TcpNativeClient) -> Result<PlayerIdentity, HandshakeCode> {
    pin! {
        let next_message = client.inner.next().fuse();
        let timeout = sleep(Duration::from_secs(30)).fuse();
    }
    let handshake: HandshakeRequest = select! {
        msg = next_message => {
            if msg.is_none() { return Err(HandshakeCode::ReadError); }
            from_str(&msg.unwrap().unwrap()).map_err(|_| HandshakeCode::ParseError)?
        },
        _ = timeout => return Err(HandshakeCode::ReadError),
    };

    let client_version =
        Version::try_from(handshake.version).map_err(|_| HandshakeCode::InvalidVersion)?;

    // Client version check
    if client_version
        < Version::try_from(CONFIG.min_client.clone()).expect("invalid client version in config")
    {
        return Err(HandshakeCode::IncompatibleVersion);
    }

    // Match token to a valid user (TODO: this is a placeholder)
    let found = Ok(PlayerIdentity {
        account_id: "TEMP".to_owned(),
        display_name: "TEMP".to_owned(),
    });
    let identity = match found {
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

pub fn deny_socket(writer: &Tx, code: HandshakeCode) -> Result<(), SendError<String>> {
    write(writer, &HandshakeResponse { code, data: None })
}

pub fn accept_socket(writer: &Tx, data: HandshakeSuccess) -> Result<(), SendError<String>> {
    write(
        writer,
        &HandshakeResponse {
            code: HandshakeCode::Ok,
            data: Some(data),
        },
    )
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
