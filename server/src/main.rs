use std::net::{Ipv4Addr, SocketAddrV4};
use tracing::{info, Level};
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

use crate::server::NetServer;

pub const VERSION: &'static str = env!("CARGO_PKG_VERSION");

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

    // Run mainloop for web server
    info!("starting Web API");
    tokio::spawn(web::main());

    // TCP server startup
    let port = config::get_integer("network.tcp_port")
        .expect("configuration key network.tcp_port not specified") as u16;
    let local_addr = SocketAddrV4::new(Ipv4Addr::LOCALHOST, port);

    let mut server = NetServer::new();
    server.set_reuseaddr_opt(true);
    server.bind(local_addr.into());

    info!("TCP connection listener bound at address {}", local_addr);
    server.run().await;
}
