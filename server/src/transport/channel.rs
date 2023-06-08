use std::{collections::HashMap, marker::PhantomData, sync::Arc};

use serde::Serialize;

use super::Tx;

pub struct Channel<T: Serialize> {
    peers: HashMap<i32, Arc<Tx>>,
    _data: PhantomData<T>,
}

impl<T: Serialize, U: Serialize> From<&Channel<U>> for Channel<T> {
    fn from(value: &Channel<U>) -> Self {
        Self {
            peers: value.peers.clone(),
            _data: PhantomData,
        }
    }
}

impl<T: Serialize> Channel<T> {
    pub fn new() -> Self {
        Self {
            peers: HashMap::new(),
            _data: PhantomData,
        }
    }

    pub fn subscribe(&mut self, address: i32, subscriber: Arc<Tx>) {
        self.peers.insert(address, subscriber);
    }

    pub fn unsubscribe(&mut self, address: i32) {
        self.peers.remove(&address);
    }

    pub fn broadcast(&mut self, message: &T) {
        let text: String = serde_json::to_string(message).expect("serialization error");
        let closed: Vec<i32> = self
            .peers
            .iter()
            .filter(|(_, peer)| peer.send(text.clone()).is_err())
            .map(|(addr, _)| *addr)
            .collect();

        for addr in closed {
            self.peers.remove(&addr);
        }
    }
}
