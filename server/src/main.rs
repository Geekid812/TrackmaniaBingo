use std::{
    net::SocketAddr,
    sync::{atomic::AtomicU32, Arc},
};
use tokio::{net::TcpSocket, sync::mpsc::unbounded_channel};
use tracing::{info, warn, Level};
use tracing_subscriber::FmtSubscriber;

pub mod core;
pub mod integrations;
pub mod orm;
pub mod server;
pub mod transport;
pub mod web;

pub mod config;

use config::CONFIG;

use crate::transport::client::tcpnative::TcpNativeClient;

pub static CLIENT_COUNT: AtomicU32 = AtomicU32::new(0);

#[tokio::main]
async fn main() {
    // Logging setup
    let subscriber = FmtSubscriber::builder()
        .with_max_level(match CONFIG.log_level.to_uppercase().as_str() {
            "TRACE" => Level::TRACE,
            "DEBUG" => Level::DEBUG,
            "INFO" => Level::INFO,
            "WARN" => Level::WARN,
            "ERROR" => Level::ERROR,
            _ => panic!("Invalid log level"),
        })
        .finish();

    tracing::subscriber::set_global_default(subscriber).expect("setting default subscriber");

    // Start web dashboard
    tokio::spawn(web::main());

    // Auth setup
    let authenticator = integrations::openplanet::Authenticator::new(
        CONFIG.secrets.openplanet_auth.clone().unwrap(),
    );
    let auth_arc = Arc::new(authenticator);
    if CONFIG.secrets.openplanet_auth.is_none() {
        info!("Openplanet authentification is disabled. This is intended to be used only on unofficial servers!");
    }
    if CONFIG.secrets.admin_key.is_none() {
        warn!("Admin key is not set, access to the admin dashboard is unrestricted. This is not recommended!");
    }

    // Setup map fetch loop
    //tokio::spawn(mapqueue::run_loop());

    // Socket creation
    let socket = TcpSocket::new_v4().expect("ipv4 socket to be created");
    socket
        .set_reuseaddr(true)
        .expect("socket to be able to be reused");
    socket
        .bind(SocketAddr::from(([0, 0, 0, 0], CONFIG.tcp_port)))
        .expect("socket address to bind");
    let listener = socket.listen(1024).expect("tcp listener to be created");
    info!(
        "listener started at address {}",
        listener.local_addr().unwrap()
    );

    loop {
        let (incoming, _) = listener
            .accept()
            .await
            .expect("incoming socket to be accepted");

        info!("accepted a connection");
        tokio::spawn(async move {
            let (tx, rx) = unbounded_channel();
            let mut client = TcpNativeClient::new(incoming, rx);

            use server::handshake::*;
            match do_handshake(&mut client).await {
                Ok(identity) => accept_socket(
                    &tx,
                    HandshakeSuccess {
                        username: identity.display_name,
                        can_reconnect: false,
                    },
                ),
                Err(e) => deny_socket(&tx, e),
            }
        });
    }
}
