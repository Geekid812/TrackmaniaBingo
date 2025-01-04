use tokio::sync::mpsc::{UnboundedReceiver, UnboundedSender};

pub mod channel;
pub mod client;
pub mod messager;
pub use channel::Channel;

// TODO: remove
pub type Tx = UnboundedSender<String>;
pub type Rx = UnboundedReceiver<String>;

pub(crate) type TransportWriteQueue = UnboundedSender<Vec<u8>>;
pub(crate) type TransportReadQueue = UnboundedReceiver<Vec<u8>>;
