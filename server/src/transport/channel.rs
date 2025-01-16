use std::{collections::HashMap, marker::PhantomData};

use serde::Serialize;

use super::messager::NetMessager;

#[derive(Clone, Debug)]
pub struct Channel<T: Serialize> {
    peers: HashMap<i32, NetMessager>,
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

    pub fn subscribe(&mut self, address: i32, subscriber: NetMessager) {
        self.peers.insert(address, subscriber);
    }

    pub fn unsubscribe(&mut self, address: i32) {
        self.peers.remove(&address);
    }

    pub fn broadcast(&mut self, message: &T) {
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

impl<T: Serialize> Default for Channel<T> {
    fn default() -> Self {
        Channel::new()
    }
}
