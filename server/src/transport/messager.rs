use std::sync::Arc;

use serde::Serialize;
use serde_json::to_string;
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

    /// Send a serialized message to the client.
    pub fn send<T: Serialize>(&self, message: &T) -> Result<(), Option<SendError<Vec<u8>>>> {
        let serialized = match to_string(message) {
            Ok(message) => message,
            Err(e) => {
                error!("serilization failure: {}", e);
                return Err(None);
            }
        };

        self.writer.send(serialized.into_bytes()).map_err(Some)
    }
}
