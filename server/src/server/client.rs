use bytes::BytesMut;
use futures::FutureExt;
use std::sync::atomic::{self, AtomicU64};
use std::time::Duration;
use tokio::net::TcpStream;
use tokio::select;
use tokio::sync::mpsc::unbounded_channel;
use tokio::time::{timeout_at, Instant};
use tracing::{debug, error};

use super::messager::{new_messager, NetMessager};
use super::{handshake, mainloop};
use crate::transport::client::tcpnative::NativeClientProtocol;
use crate::transport::{TransportReader, TransportWriter};

/// Unique identifier for debugging, so that we don't use something identifiable like IP addresses.
static CLIENT_ID: AtomicU64 = AtomicU64::new(0);

/// Manages the lifecycle of a single connection from `NetServer`.
pub struct NetClient {
    cid: u64,
    protocol: NativeClientProtocol,
    messager: NetMessager,
    receiver: TransportReader,
    timeout: Duration,
    callback_mode: ClientCallbackImplementation,
}

impl NetClient {
    /// Create a new `NetClient`.
    pub fn new(stream: TcpStream, timeout: Duration) -> Self {
        let (tx, rx): (TransportWriter, TransportReader) = unbounded_channel();
        Self {
            cid: CLIENT_ID.fetch_add(1, atomic::Ordering::Relaxed),
            protocol: NativeClientProtocol::new(stream),
            messager: new_messager(tx),
            receiver: rx,
            timeout,
            callback_mode: ClientCallbackImplementation::None,
        }
    }

    /// Get the internal debug ID.
    pub fn cid(&self) -> u64 {
        self.cid
    }

    /// Get a handle to the `NetMessager` of this connection.
    pub fn messager(&self) -> NetMessager {
        self.messager.clone()
    }

    /// Sets the event handlers to dispatch to a specific implementation of the callbacks.
    pub fn set_callback_mode(&mut self, mode: ClientCallbackImplementation) {
        self.callback_mode = mode;
    }

    /// Handler for all incoming messages. Returns a boolean of whether to keep the connection alive.
    async fn handle_message(&mut self, bytes: BytesMut) -> bool {
        match self.callback_mode.clone() {
            ClientCallbackImplementation::Handshake => {
                handshake::handshake_message_received(self, bytes).await
            }
            ClientCallbackImplementation::Mainloop => {
                mainloop::mainloop_message_received(self, bytes).await
            }
            _ => {
                debug!(cid = self.cid(), "message event was dropped");
                false
            }
        }
    }

    /// Handler for closing the connection.
    async fn handle_close(&mut self) {
        debug!(cid = self.cid(), "close event was dropped");
    }

    /// Run the main loop of the client.
    pub async fn run(mut self) {
        let mut timeout_deadline = Instant::now() + self.timeout;
        loop {
            let next_message_received =
                timeout_at(timeout_deadline, self.protocol.receive_message().fuse());
            let outgoing_message_queued = self.receiver.recv().fuse();

            select! {
                timed_result = next_message_received => match timed_result {
                    Ok(option_message) => match option_message {
                        Some(result) => match result {
                            Ok(message) => {
                                let keep_alive = self.handle_message(message).await;

                                if !keep_alive {
                                    break;
                                }

                                timeout_deadline = Instant::now() + self.timeout;
                            },
                            Err(err) => {
                                error!(cid = self.cid, "socket read error: {}", err);
                                break;
                            }
                        },
                        None => {
                            debug!(cid = self.cid, "closed connection by remote client");
                            break;
                        }
                    },
                    Err(timeout) => {
                        debug!(cid = self.cid, "timed out: {}", timeout);
                        break;
                    }
                },
                queued_message = outgoing_message_queued => match queued_message {
                    Some(message) => match self.protocol.write(message).await {
                        Ok(()) => (),
                        Err(err) => {
                            error!(cid = self.cid, "socket write error: {}", err);
                            break;
                        }
                    },
                    None => {
                        error!(
                            cid = self.cid,
                            "all messagers have been dropped! this should not have happened since we are holding one ourselves."
                        );
                        break;
                    }
                }
            }
        }

        self.handle_close().await;
    }
}

/// The different callback implementations for `NetClient`.
#[derive(Debug, Clone)]
pub enum ClientCallbackImplementation {
    Handshake,
    Mainloop,
    None,
}
