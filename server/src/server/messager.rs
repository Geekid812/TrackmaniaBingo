use std::sync::Arc;

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
}
