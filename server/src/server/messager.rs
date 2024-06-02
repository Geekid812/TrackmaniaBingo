use std::sync::Arc;

use serde::Serialize;
use serde_json::to_string;
use tracing::error;

use crate::transport::TransportWriter;

pub type NetMessager = Arc<NetMessageWriter>;

pub fn new_messager(writer: TransportWriter) -> NetMessager {
    Arc::new(NetMessageWriter::new(writer))
}

pub struct NetMessageWriter {
    writer: TransportWriter,
}

impl NetMessageWriter {
    pub fn new(writer: TransportWriter) -> Self {
        Self { writer }
    }

    /// Send a serialized message to the client.
    pub fn send<T: Serialize>(&self, message: &T) {
        let serialized = match to_string(message) {
            Ok(message) => message,
            Err(e) => {
                error!("serilization failure: {}", e);
                return;
            }
        };

        self.writer.send(serialized.into_bytes());
    }
}
