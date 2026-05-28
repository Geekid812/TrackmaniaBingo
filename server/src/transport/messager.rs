use bytes::Bytes;
use std::sync::Arc;

use serde::Serialize;
use serde_json::to_vec;
use tokio::sync::mpsc::error::SendError;
use tracing::error;

use crate::transport::TransportWriteQueue;

pub type NetMessager = Arc<NetMessageWriter>;

pub fn new_messager(writer: TransportWriteQueue) -> NetMessager {
    Arc::new(NetMessageWriter::new(writer))
}

#[derive(Debug)]
pub struct NetMessageWriter {
    writer: TransportWriteQueue,
}

impl NetMessageWriter {
    pub fn new(writer: TransportWriteQueue) -> Self {
        Self { writer }
    }

    pub fn send_serialized(&self, message: Bytes) -> Result<(), SendError<Bytes>> {
        self.writer.send(message)
    }

    /// Send a serialized message to the client.
    pub fn send<T: Serialize>(&self, message: &T) -> Result<(), Option<SendError<Bytes>>> {
        let serialized = match to_vec(message) {
            Ok(message) => Bytes::from(message),
            Err(e) => {
                error!("serilization failure: {}", e);
                return Err(None);
            }
        };

        self.send_serialized(serialized).map_err(Some)
    }
}
