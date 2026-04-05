use std::collections::HashMap;

use serde::Serialize;
use serde_json::to_vec;
use tracing::error;

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

    pub fn peer_count(&self) -> usize {
        self.peers.len()
    }

    pub fn broadcast(&mut self, message: &impl Serialize) {
        let serialized = match to_vec(message) {
            Ok(message) => message,
            Err(e) => {
                error!("broadcast serialization failure: {}", e);
                return;
            }
        };

        let closed: Vec<i32> = self
            .peers
            .iter()
            .filter(|(_, peer)| peer.send_raw(serialized.clone()).is_err_and(|e| e.is_some()))
            .map(|(addr, _)| *addr)
            .collect();

        for addr in closed {
            self.peers.remove(&addr);
        }
    }
}
