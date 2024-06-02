use bytes::BytesMut;
use futures::{Future, FutureExt};
use std::pin::Pin;
use std::sync::atomic::{self, AtomicU64};
use std::sync::Arc;
use std::time::Duration;
use std::{future, io};
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
    callbacks: NetClientCallbacks,
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
            callbacks: NetClientCallbacks::new(),
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

    /// Handler for all incoming messages.
    async fn handle_message(&mut self, bytes: BytesMut) {
        let callback = self.callbacks.wrap_message_handler();
        callback(self, bytes).await;
    }

    /// Handler for closing the connection.
    async fn handle_close(&mut self) {
        let callback = self.callbacks.wrap_close_handler();
        callback(self).await;
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

/// Return type for an async callback.
type PinFuture<Output> = Pin<Box<dyn Send + Future<Output = Output>>>;

/// Internal callback state of `NetClient`.
struct NetClientCallbacks<Message = BytesMut> {
    message_handler: Option<Arc<dyn Send + Sync + Fn(&mut NetClient, Message) -> PinFuture<()>>>,
    close_handler: Option<Arc<dyn Send + Sync + Fn(&mut NetClient) -> PinFuture<()>>>,
}

impl<Message> NetClientCallbacks<Message> {
    /// Create a new `NetClient`.
    pub fn new() -> Self {
        Self {
            message_handler: None,
            close_handler: None,
        }
    }

    /// Sets the message handler to a provided callback.
    pub fn set_message_handler<F>(&mut self, handler: F)
    where
        F: 'static + Send + Sync + Fn(&mut NetClient, Message) -> PinFuture<()>,
    {
        self.message_handler = Some(Arc::new(handler));
    }

    /// Sets the close handler to a provided callback.
    pub fn set_close_handler<F>(&mut self, handler: F)
    where
        F: 'static + Send + Sync + Fn(&mut NetClient) -> PinFuture<()>,
    {
        self.close_handler = Some(Arc::new(handler));
    }

    /// Return a closure that calls the async message handler.
    pub fn wrap_message_handler(&self) -> impl FnOnce(&mut NetClient, Message) -> PinFuture<()> {
        let opt_handler = self.message_handler.clone();
        |client, message| {
            if let Some(handler) = opt_handler {
                return handler(client, message);
            }
            Box::pin(future::ready(()))
        }
    }

    /// Return a closure that calls the async close handler.
    pub fn wrap_close_handler(&self) -> impl FnOnce(&mut NetClient) -> PinFuture<()> {
        let opt_handler = self.close_handler.clone();
        |client: &mut NetClient| {
            if let Some(handler) = opt_handler {
                return handler(client);
            }
            Box::pin(future::ready(()))
        }
    }
}

/// Static assertion to check that a type implements Send and Sync.
#[allow(dead_code)]
const fn assert_is_send_sync<T: Send + Sync>() {}

const _: () = assert_is_send_sync::<NetClientCallbacks>();
const _: () = assert_is_send_sync::<NetClient>();

// -- old code
fn handle_recv(ctx: &mut ClientContext, result: Result<String, io::Error>) -> bool {
    let msg = match result {
        Ok(msg) => msg,
        Err(_) => return false,
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
