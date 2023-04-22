use tracing::debug;

use crate::{socket::SocketAction, util::sink::WriteSink};

// pub type ChannelAddress = generational_arena::Index;
// static CHANNELS: Mutex<Lazy<Arena<Vec<WriteSink>>>> = Mutex::new(Lazy::new(|| Arena::new()));

pub struct Channel(Vec<WriteSink>);

impl Channel {
    pub fn new() -> Self {
        Self(Vec::new())
    }

    pub fn subscribe(&mut self, target: WriteSink) {
        self.0.push(target)
    }

    pub fn cleanup(&mut self) {
        self.0 = self
            .0
            .iter()
            .filter(|sink| sink.is_alive())
            .map(WriteSink::clone)
            .collect();
    }

    pub fn broadcast(&self, message: String) {
        debug!("broadcasting: {}", message);
        self.0.iter().for_each(|sink| {
            sink.writer()
                .map(|sender| sender.send(SocketAction::Message(message.clone())));
        });
    }
}

// pub fn new() -> ChannelAddress {
//     CHANNELS.lock().insert(Vec::new())
// }

// pub fn get<'a>(address: ChannelAddress) -> Option<Channel<'a>> {
//     CHANNELS.lock().get_mut(address).map(|c| Channel(c))
// }

// pub fn remove(address: ChannelAddress) -> bool {
//     CHANNELS.lock().remove(address).is_some()
// }
