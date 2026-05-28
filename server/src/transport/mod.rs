use bytes::Bytes;
use tokio::sync::mpsc::{UnboundedReceiver, UnboundedSender};

pub mod channel;
pub mod client;
pub mod messager;
pub use channel::Channel;

pub(crate) type TransportWriteQueue = UnboundedSender<Bytes>;
pub(crate) type TransportReadQueue = UnboundedReceiver<Bytes>;
