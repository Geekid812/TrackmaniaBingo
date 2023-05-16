use std::io;
use std::time::Duration;

use diesel::prelude::*;
use diesel::result::Error::NotFound;
use futures::{select, FutureExt, StreamExt};
use serde::{Deserialize, Serialize};
use serde_json::from_str;
use serde_repr::Serialize_repr;
use tokio::pin;
use tokio::time::sleep;
use tracing::error;

use super::version::Version;
use crate::orm;
use crate::orm::models::player::Player;
use crate::{transport::client::tcpnative::TcpNativeClient, CONFIG};

pub async fn do_handshake(client: &mut TcpNativeClient) -> Result<Player, HandshakeCode> {
    pin! {
        let next_message = client.inner.next().fuse();
        let timeout = sleep(Duration::from_secs(30)).fuse();
    }
    let handshake: HandshakeRequest = select! {
        msg = next_message => {
            if msg.is_none() { return Err(HandshakeCode::ReadError); }
            match &msg.unwrap() {
                Ok(handshake_msg) => from_str(handshake_msg).map_err(|_| HandshakeCode::ParseError)?,
                Err(e) => {
                    error!("{}", e);
                    return Err(HandshakeCode::ReadError);
                },
            }
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

    // Match token to a valid user in storage
    let player_record = orm::execute(|conn| {
        use crate::orm::schema::players::dsl::*;
        players
            .filter(client_token.eq(handshake.token))
            .first::<Player>(conn)
    })
    .await
    .expect("database execute error");

    let profile = match player_record {
        Ok(player) => player,
        Err(e) => {
            return Err(match e {
                NotFound => HandshakeCode::AuthRefused,
                _ => {
                    error!("Auth failure: {:?}", e);
                    HandshakeCode::AuthFailure
                }
            })
        }
    };

    return Ok(profile);
}

pub async fn deny_socket(
    client: &mut TcpNativeClient,
    code: HandshakeCode,
) -> Result<(), io::Error> {
    client.write(&HandshakeResponse { code, data: None }).await
}

pub async fn accept_socket(
    client: &mut TcpNativeClient,
    data: HandshakeSuccess,
) -> Result<(), io::Error> {
    client
        .write(&HandshakeResponse {
            code: HandshakeCode::Ok,
            data: Some(data),
        })
        .await
}

#[derive(Deserialize)]
struct HandshakeRequest {
    version: String,
    token: String,
}

#[derive(Serialize)]
struct HandshakeResponse {
    code: HandshakeCode,
    #[serde(flatten, skip_serializing_if = "Option::is_none")]
    data: Option<HandshakeSuccess>,
}

#[derive(Serialize)]
pub struct HandshakeSuccess {
    pub profile: Player,
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