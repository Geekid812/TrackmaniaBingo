use std::collections::HashMap;

use serde::Serialize;

use super::messager::NetMessager;

#[derive(Clone, Debug, Default)]
pub struct Channel {
    peers: HashMap<i32, NetMessager>,
}

impl Channel {
    pub fn new() -> Self {
        Self {
            peers: HashMap::new(),
        }
    }

    pub fn subscribe(&mut self, address: i32, subscriber: NetMessager) {
        self.peers.insert(address, subscriber);
    }

    pub fn unsubscribe(&mut self, address: i32) {
        self.peers.remove(&address);
    }

    pub fn broadcast(&mut self, message: &impl Serialize) {
        // send message to all peers and collect closed connections which produced an error
        let closed: Vec<i32> = self
            .peers
            .iter()
            .filter(|(_, peer)| peer.send(message).is_err_and(|e| e.is_some()))
            .map(|(addr, _)| *addr)
            .collect();

        for addr in closed {
            self.peers.remove(&addr);
        }
    }
}
