use tokio::sync::mpsc::{UnboundedReceiver, UnboundedSender};

pub mod channel;
pub mod client;
pub use channel::Channel;

// TODO: remove
pub type Tx = UnboundedSender<String>;
pub type Rx = UnboundedReceiver<String>;

pub(crate) type TransportWriter = UnboundedSender<Vec<u8>>;
pub(crate) type TransportReader = UnboundedReceiver<Vec<u8>>;
