use tokio::net::TcpStream;
use tokio_util::codec::{Framed, LengthDelimitedCodec};

use crate::Rx;

pub struct TcpNativeClient {
    pub inner: Framed<TcpStream, LengthDelimitedCodec>,
    pub rx: Rx,
}

impl TcpNativeClient {
    pub fn new(stream: TcpStream, rx: Rx) -> Self {
        Self {
            inner: Framed::new(stream, LengthDelimitedCodec::new()),
            rx,
        }
    }
}
