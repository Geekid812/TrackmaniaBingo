use std::io;

use bytes::BytesMut;
use futures::{SinkExt, StreamExt};
use serde::Serialize;
use tokio::{net::TcpStream, sync::mpsc::error::SendError};
use tokio_util::codec::{Framed, LengthDelimitedCodec};

use super::TransportWriter;

pub struct NativeClientProtocol {
    inner: Framed<TcpStream, LengthDelimitedCodec>,
}

impl NativeClientProtocol {
    pub fn new(stream: TcpStream) -> Self {
        let length_codec = LengthDelimitedCodec::builder().little_endian().new_codec();
        Self {
            inner: Framed::new(stream, length_codec),
        }
    }

    pub async fn receive_message(&mut self) -> Option<Result<BytesMut, io::Error>> {
        self.inner.next().await
    }

    pub async fn write(&mut self, message: Vec<u8>) -> Result<(), io::Error> {
        self.inner.send(message.into()).await
    }
}

pub fn write<S: Serialize>(tx: &TransportWriter, value: &S) -> Result<(), SendError<Vec<u8>>> {
    tx.send(
        serde_json::to_string(value)
            .expect("Serialize should not error")
            .into(),
    )
}
