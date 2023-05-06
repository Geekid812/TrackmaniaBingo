use bytes::{Bytes, BytesMut};
use serde::Serialize;
use tokio::{net::TcpStream, sync::mpsc::error::SendError};
use tokio_util::codec::{Decoder, Encoder, Framed, LengthDelimitedCodec};

use crate::transport::Tx;

use super::Rx;

pub struct TcpNativeClient {
    pub inner: Framed<TcpStream, StringCodec<LengthDelimitedCodec>>,
    pub rx: Rx,
}

impl TcpNativeClient {
    pub fn new(stream: TcpStream, rx: Rx) -> Self {
        Self {
            inner: Framed::new(stream, StringCodec::new(LengthDelimitedCodec::new())),
            rx,
        }
    }
}

pub fn write<S: Serialize>(tx: &Tx, value: &S) -> Result<(), SendError<String>> {
    tx.send(serde_json::to_string(value).expect("Serialize should not error in write"))
}

pub struct StringCodec<C: Decoder + Encoder<Bytes>> {
    codec: C,
}

impl<C: Decoder + Encoder<Bytes>> StringCodec<C> {
    pub fn new(codec: C) -> Self {
        Self { codec }
    }

    fn inner_decode(
        &mut self,
        decoded: Result<Option<BytesMut>, <C as Decoder>::Error>,
    ) -> Result<Option<String>, <C as Decoder>::Error> {
        match decoded {
            Ok(Some(bytes)) => Ok(Some(
                String::from_utf8(bytes.to_vec()).expect("Decoder expects valid UTF-8"),
            )),
            Ok(None) => Ok(None),
            Err(e) => Err(e),
        }
    }
}

impl<C: Decoder<Item = BytesMut> + Encoder<Bytes>> Decoder for StringCodec<C> {
    type Item = String;
    type Error = <C as Decoder>::Error;

    fn decode(&mut self, src: &mut BytesMut) -> Result<Option<Self::Item>, Self::Error> {
        let decoded = self.codec.decode(src);
        self.inner_decode(decoded)
    }

    fn decode_eof(&mut self, buf: &mut BytesMut) -> Result<Option<Self::Item>, Self::Error> {
        let decoded = self.codec.decode_eof(buf);
        self.inner_decode(decoded)
    }
}

impl<C: Decoder + Encoder<Bytes>> Encoder<String> for StringCodec<C> {
    type Error = <C as Encoder<Bytes>>::Error;

    fn encode(&mut self, item: String, dst: &mut BytesMut) -> Result<(), Self::Error> {
        self.codec
            .encode(Bytes::copy_from_slice(item.as_bytes()), dst)
    }
}
