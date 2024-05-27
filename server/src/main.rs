use std::sync::Arc;
use std::{net::SocketAddr, sync::atomic::AtomicU32};
use tokio::{net::TcpSocket, sync::mpsc::unbounded_channel};
use tracing::{info, warn, Level};
use tracing_subscriber::FmtSubscriber;

pub mod core;
pub mod datatypes;
pub mod integrations;
pub mod orm;
pub mod server;
pub mod store;
pub mod transport;
pub mod web;

pub mod config;

use config::CONFIG;

use crate::server::client;
use crate::server::context::ClientContext;
use crate::transport::client::tcpnative::TcpNativeClient;

pub const VERSION: &'static str = env!("CARGO_PKG_VERSION");
pub static CLIENT_COUNT: AtomicU32 = AtomicU32::new(0);

#[tokio::main]
async fn main() {
    // Logging setup
    let subscriber = FmtSubscriber::builder()
        .with_max_level(Level::DEBUG)
        .finish();
    tracing::subscriber::set_global_default(subscriber).expect("logging could not be initialized");

    info!("Trackmania Bingo Server: Version {VERSION}");

    // Load configuration
    config::initialize();
    config::enumerate_keys();

    // Database setup
    info!("opening main database store");
    store::initialize_primary_store("main.db").await;

    orm::start_database(&CONFIG.database_url).await;
    orm::mapcache::start_database(&CONFIG.mapcache_url).await;

    // Start web dashboard
    tokio::spawn(web::main());

    if CONFIG.secrets.openplanet_auth.is_none() {
        info!("Openplanet authentification is disabled. This is intended to be used only on unofficial servers!");
    }
    if CONFIG.secrets.admin_key.is_none() {
        warn!("Admin key is not set, access to the admin dashboard is unrestricted. This is not recommended!");
    }

    // Setup daily challenge
    tokio::spawn(server::daily::run_loop());

    // Socket creation
    let socket = TcpSocket::new_v4().expect("ipv4 socket to be created");
    socket
        .set_reuseaddr(true)
        .expect("socket to be able to be reused");
    socket
        .bind(SocketAddr::from((
            [0, 0, 0, 0],
            config::get_integer("network.tcp_port").expect("key network.tcp_port not set") as u16,
        )))
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
            let profile = match do_handshake(&mut client).await {
                Ok(profile) => {
                    accept_socket(
                        &mut client,
                        HandshakeSuccess {
                            profile: profile.clone(),
                            can_reconnect: false,
                        },
                    )
                    .await
                    .ok();
                    Some(profile)
                }
                Err(e) => deny_socket(&mut client, e).await.ok().and(None),
            };
            if profile.is_none() {
                return;
            }
            let ctx = ClientContext::new(profile.unwrap(), Arc::new(tx));
            client::run_loop(ctx, client).await;
            info!("dropping connection");
        });
    }
}
