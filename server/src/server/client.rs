use bytes::BytesMut;
use futures::FutureExt;
use std::sync::atomic::{self, AtomicU64};
use std::time::Duration;
use tokio::net::TcpStream;
use tokio::select;
use tokio::sync::mpsc::unbounded_channel;
use tokio::time::{timeout_at, Instant};
use tracing::{debug, error, warn};

use super::handshake;
use super::requests::BaseRequest;
use crate::server::context::ClientContext;
use crate::transport::client::tcpnative::NativeClientProtocol;
use crate::transport::messager::{new_messager, NetMessager};
use crate::transport::{TransportReadQueue, TransportWriteQueue};

/// Unique identifier for debugging, so that we don't use something identifiable like IP addresses.
static CLIENT_ID: AtomicU64 = AtomicU64::new(0);

/// Manages the lifecycle of a single connection from `NetServer`.
pub struct NetClient {
    cid: u64,
    protocol: NativeClientProtocol,
    messager: NetMessager,
    receiver: TransportReadQueue,
    timeout: Duration,
    callback_mode: ClientCallbackImplementation,
    context: Option<ClientContext>,
}

impl NetClient {
    /// Create a new `NetClient`.
    pub fn new(stream: TcpStream, timeout: Duration) -> Self {
        let (tx, rx): (TransportWriteQueue, TransportReadQueue) = unbounded_channel();
        Self {
            cid: CLIENT_ID.fetch_add(1, atomic::Ordering::Relaxed),
            protocol: NativeClientProtocol::new(stream),
            messager: new_messager(tx),
            receiver: rx,
            timeout,
            callback_mode: ClientCallbackImplementation::None,
            context: None,
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

    /// Sets the inner `ClientContext`.
    pub fn set_context(&mut self, context: Option<ClientContext>) {
        self.context = context;
    }

    /// Handler for all incoming messages.
    async fn handle_message(&mut self, bytes: BytesMut) {
        match self.callback_mode.clone() {
            ClientCallbackImplementation::Handshake => {
                handshake::handshake_message_received(self, bytes).await
            }
            ClientCallbackImplementation::Mainloop => {
                mainloop_message_received(self, bytes).await;
            }
            _ => debug!(cid = self.cid(), "message event was dropped"),
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
                                self.handle_message(message).await;
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

async fn mainloop_message_received(client: &mut NetClient, message: BytesMut) -> bool {
    let cid = client.cid();
    let Some(ctx) = &mut client.context else {
        error!(cid = cid, "mainloop message received with no context");
        return false;
    };

    let message = match String::from_utf8(message.to_vec()) {
        Ok(str) => str,
        Err(e) => {
            error!(
                cid = client.cid(),
                "received a non-utf8 message in mainloop: {}", e
            );
            return false;
        }
    };
    debug!(cid = cid, message = message);

    // Match a request
    match serde_json::from_str::<BaseRequest>(&message) {
        Ok(incoming) => {
            let response = incoming.request.handle(ctx);
            let outgoing = incoming.build_reply(response);

            // send a response. if it's an error, break the connection
            if ctx.writer.send(&outgoing).is_err() {
                return false;
            }
        }
        Err(e) => warn!(cid = cid, "Unknown message received: {e}"),
    };
    true
}
