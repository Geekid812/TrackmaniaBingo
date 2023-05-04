use std::{collections::HashMap, marker::PhantomData};

use serde::Serialize;

use crate::Tx;

pub struct Channel<T: Serialize> {
    peers: HashMap<String, Tx>,
    _data: PhantomData<T>,
}

impl<T: Serialize> Channel<T> {
    pub fn new() -> Self {
        Self {
            peers: HashMap::new(),
            _data: PhantomData,
        }
    }

    pub fn subscribe(&mut self, address: String, subscriber: Tx) {
        self.peers.insert(address, subscriber);
    }

    pub fn unsubscribe(&mut self, address: &str) {
        self.peers.remove(address);
    }

    pub fn broadcast(&mut self, message: &T) {
        let text: String = serde_json::to_string(message).expect("serialization error");
        let closed: Vec<String> = self
            .peers
            .iter()
            .filter(|(_, peer)| peer.send(text.clone()).is_err())
            .map(|(addr, _)| addr.clone())
            .collect();

        for addr in closed {
            self.peers.remove(&addr);
        }
    }
}
