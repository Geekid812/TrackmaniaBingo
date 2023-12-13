use std::io;
use std::sync::atomic::{AtomicI32, Ordering};
use std::time::Duration;

use chrono::NaiveDateTime;
use futures::executor::block_on;
use futures::{select, FutureExt, StreamExt};
use serde::Serialize;
use serde_json::from_str;
use serde_repr::Serialize_repr;
use sqlx::FromRow;
use tokio::pin;
use tokio::time::sleep;
use tracing::{debug, error};

use super::version::Version;
use crate::datatypes::{GamePlatform, HandshakeRequest};
use crate::orm;
use crate::orm::composed::profile::{get_profile, PlayerProfile};
use crate::orm::models::player::Player;
use crate::{transport::client::tcpnative::TcpNativeClient, CONFIG};

static EHPEMERAL_UID: AtomicI32 = AtomicI32::new(-1000);

pub async fn do_handshake(client: &mut TcpNativeClient) -> Result<PlayerProfile, HandshakeCode> {
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
        Version::try_from(handshake.version.clone()).map_err(|_| HandshakeCode::InvalidVersion)?;

    // Client version check
    if client_version
        < Version::try_from(CONFIG.min_client.clone()).expect("invalid client version in config")
    {
        return Err(HandshakeCode::IncompatibleVersion);
    }

    if is_ephemeral_player(&handshake) {
        if let Some(name) = handshake.username {
            return Ok(PlayerProfile {
                player: Player {
                    uid: EHPEMERAL_UID.fetch_add(-1, Ordering::Relaxed),
                    username: name,
                    ..Player::default()
                },
                ..PlayerProfile::default()
            });
        } else {
            return Err(HandshakeCode::NoUsername);
        }
    }

    // Match token to a valid user in storage
    let player_record = orm::execute(|mut conn| {
        let query =
            sqlx::query("SELECT * FROM players WHERE client_token = ?").bind(handshake.token);
        let row = block_on(query.fetch_one(&mut *conn))?;
        let player = Player::from_row(&row).expect("Player from_row failed");
        block_on(get_profile(&mut conn, player))
    })
    .await;

    let profile = match player_record {
        Ok(player) => player,
        Err(e) => {
            return Err(match e {
                sqlx::Error::RowNotFound => HandshakeCode::AuthRefused,
                _ => {
                    error!("Auth failure: {:?}", e);
                    HandshakeCode::AuthFailure
                }
            })
        }
    };

    return Ok(profile);
}

fn is_ephemeral_player(request: &HandshakeRequest) -> bool {
    // In Turbo, player profiles are not saved
    return request.game == GamePlatform::Turbo;
}

pub async fn deny_socket(
    client: &mut TcpNativeClient,
    code: HandshakeCode,
) -> Result<(), io::Error> {
    client
        .serialize(&HandshakeResponse { code, data: None })
        .await
}

pub async fn accept_socket(
    client: &mut TcpNativeClient,
    data: HandshakeSuccess,
) -> Result<(), io::Error> {
    debug!("acceptance");
    client
        .serialize(&HandshakeResponse {
            code: HandshakeCode::Ok,
            data: Some(data),
        })
        .await
}

#[derive(Serialize)]
struct HandshakeResponse {
    code: HandshakeCode,
    #[serde(flatten, skip_serializing_if = "Option::is_none")]
    data: Option<HandshakeSuccess>,
}

#[derive(Serialize)]
pub struct HandshakeSuccess {
    pub profile: PlayerProfile,
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
