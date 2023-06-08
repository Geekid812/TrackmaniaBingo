use std::{
    collections::HashMap,
    hash::Hash,
    sync::{Arc, Weak},
};

use once_cell::sync::Lazy;
use parking_lot::{Mutex, MutexGuard};

use crate::transport::Channel;

use super::{
    events::roomlist::RoomlistEvent, livegame::LiveMatch, room::GameRoom,
    util::roomcode::generate_roomcode,
};

pub static ROOMS: Directory<String, GameRoom> = Directory::new();
pub static MATCHES: Directory<String, LiveMatch> = Directory::new();

static PUB_ROOMS_CHANNEL: Mutex<Lazy<Channel<RoomlistEvent>>> =
    Mutex::new(Lazy::new(|| Channel::new()));

pub struct Directory<K, T> {
    inner: Mutex<Lazy<HashMap<K, Owned<T>>>>,
}

pub type Owned<T> = Arc<Mutex<T>>;
pub type Shared<T> = Weak<Mutex<T>>;
pub type Locked<'a, K, T> = MutexGuard<'a, Lazy<HashMap<K, Owned<T>>>>;

impl<K: Hash + Eq + Clone, T> Directory<K, T> {
    pub const fn new() -> Self {
        Self {
            inner: Mutex::new(Lazy::new(|| HashMap::new())),
        }
    }

    pub fn register<'a>(&self, key: K, item: T) -> Owned<T> {
        let mut lock = self.inner.lock();

        let arc = Arc::new(Mutex::new(item));
        lock.insert(key, arc.clone());
        arc
    }

    pub fn find(&self, key: K) -> Option<Owned<T>> {
        self.inner.lock().get(&key).map(|arc| arc.clone())
    }

    pub fn remove(&self, key: K) {
        self.inner.lock().remove(&key);
    }

    pub fn remove_item(&self, room: Owned<T>) {
        let mut lock = self.inner.lock();

        let to_remove = lock
            .iter()
            .filter(|(_, arc)| Arc::ptr_eq(&room, arc))
            .map(|(key, _)| key.clone())
            .next();

        if let Some(key) = to_remove {
            lock.remove(&key);
        }
    }

    pub fn lock<'a>(&'a self) -> Locked<'a, K, T> {
        self.inner.lock()
    }
}

pub fn get_new_roomcode() -> String {
    let lock = ROOMS.lock();
    let mut join_code = generate_roomcode();

    while lock.get(&join_code).is_some() {
        join_code = generate_roomcode();
    }

    join_code
}

pub fn send_room_visibility(room: &GameRoom, visible: bool) {
    let mut lock = PUB_ROOMS_CHANNEL.lock();
    if !visible {
        lock.broadcast(&RoomlistEvent::RoomUnlisted {
            join_code: room.join_code().to_owned(),
        });
    } else {
        lock.broadcast(&RoomlistEvent::RoomListed { room: room.into() })
    }
}
