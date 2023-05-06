use tokio::sync::mpsc::{UnboundedReceiver, UnboundedSender};

pub mod channel;
pub mod client;
pub use channel::Channel;

pub(crate) type Tx = UnboundedSender<String>;
pub(crate) type Rx = UnboundedReceiver<String>;
