use bytes::BytesMut;
use futures::FutureExt;
use std::io;
use std::sync::atomic::{self, AtomicU64};
use std::time::Duration;
use tokio::net::TcpStream;
use tokio::select;
use tokio::sync::mpsc::unbounded_channel;
use tokio::time::{timeout_at, Instant};
use tracing::{debug, error, warn};

use super::messager::{new_messager, NetMessager};
use super::requests::BaseRequest;
use crate::server::context::ClientContext;
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
        }
    }

    /// Get the internal debug ID.
    pub fn cid(&self) -> u64 {
        self.cid
    }

    /// Generic handler for all incoming messages.
    fn handle_message(&mut self, bytes: BytesMut) {}

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
                                self.handle_message(message);
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
    }
}

fn handle_recv(ctx: &mut ClientContext, result: Result<String, io::Error>) -> bool {
    let msg = match result {
        Ok(msg) => msg,
        Err(e) => return false,
    };
    debug!("received: {}", msg);

    // Match a request
    match serde_json::from_str::<BaseRequest>(&msg) {
        Ok(incoming) => {
            let response = incoming.request.handle(ctx);
            let outgoing = incoming.build_reply(response);
            let res_text = serde_json::to_string(&outgoing).expect("response serialization failed");
            debug!("response: {}", &res_text);
            let sent = ctx.writer.send(res_text);
            if sent.is_err() {
                return false; // Explicit disconnect
            }
        }
        Err(e) => warn!("Unknown message received: {e}"),
    };
    true
}
