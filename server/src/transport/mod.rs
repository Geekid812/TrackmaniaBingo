use tokio::sync::mpsc::{Receiver, Sender};

pub mod channel;
pub mod client;
pub mod messager;
pub use channel::Channel;

pub(crate) const CLIENT_CHANNEL_CAPACITY: usize = 2048;

pub(crate) type TransportWriteQueue = Sender<Vec<u8>>;
pub(crate) type TransportReadQueue = Receiver<Vec<u8>>;
