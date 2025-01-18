use std::{net::SocketAddr, time::Duration};

use client::ClientCallbackImplementation;
use tokio::net::TcpSocket;
use tracing::debug;

use crate::{config, server::client::NetClient};

mod client;
pub mod context;
pub mod handlers;
pub mod handshake;
pub mod mapload;
pub mod requests;
pub mod tasks;
mod version;
mod auth;

/// Main TCP server internal structure that listens to incoming player connections.
pub struct NetServer {
    socket: TcpSocket,
}

impl NetServer {
    /// Create a new `NetServer`.
    pub fn new() -> Self {
        Self {
            socket: TcpSocket::new_v4().expect("failed to create new IPv4 socket"),
        }
    }

    /// Set the reuse address flag on the internal socket.
    pub fn set_reuseaddr_opt(&mut self, enable: bool) {
        self.socket
            .set_reuseaddr(enable)
            .expect("unable to set reuseaddr option");
    }

    /// Bind the internal socket to the specified address.
    pub fn bind(&mut self, addr: SocketAddr) {
        self.socket.bind(addr).expect("binding socket failed");
    }

    /// Run the main server loop.
    pub async fn run(self) {
        let client_timeout = get_client_timeout_config();
        let listener = self.socket.listen(256).expect("TCP listener not created");

        loop {
            let (incoming, remote_addr) = listener
                .accept()
                .await
                .expect("failed to accept an incoming connection");

            let mut client = NetClient::new(incoming, client_timeout);
            client.set_callback_mode(ClientCallbackImplementation::Handshake);
            debug!(cid = client.cid(), "new connection: {}", remote_addr);
            tokio::spawn(async move { client.run().await });
        }
    }
}

/// Get the TCP timeout duration from the configuration.
fn get_client_timeout_config() -> Duration {
    Duration::from_secs(
        config::get_integer("network.timeout")
            .expect("configuration key network.timeout not specified")
            .try_into()
            .expect("configuration value network.timeout is out of range"),
    )
}
