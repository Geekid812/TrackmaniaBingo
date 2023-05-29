use std::{
    collections::HashMap,
    sync::{Arc, Weak},
};

use once_cell::sync::Lazy;
use parking_lot::{Mutex, MutexGuard};

use crate::transport::Channel;

use super::{events::roomlist::RoomlistEvent, room::GameRoom, util::roomcode::generate_roomcode};

pub type OwnedRoom = Arc<Mutex<GameRoom>>;
pub type SharedRoom = Weak<Mutex<GameRoom>>;

static ROOMS: Mutex<Lazy<HashMap<String, OwnedRoom>>> = Mutex::new(Lazy::new(|| HashMap::new()));
static PUB_ROOMS_CHANNEL: Mutex<Lazy<Channel<RoomlistEvent>>> =
    Mutex::new(Lazy::new(|| Channel::new()));
pub type RoomsLock<'a> = MutexGuard<'a, Lazy<HashMap<String, OwnedRoom>>>;

pub fn register_room<'a>(room: GameRoom) -> OwnedRoom {
    let mut lock = ROOMS.lock();

    let join_code = room.join_code().to_owned();
    let room = Arc::new(Mutex::new(room));
    lock.insert(join_code, room.clone());
    room
}

pub fn get_new_roomcode() -> String {
    let lock = ROOMS.lock();
    let mut join_code = generate_roomcode();

    while lock.get(&join_code).is_some() {
        join_code = generate_roomcode();
    }

    join_code
}

pub fn find_room(join_code: String) -> Option<OwnedRoom> {
    ROOMS.lock().get(&join_code).map(|arc| arc.clone())
}

pub fn remove_code(join_code: String) {
    ROOMS.lock().remove(&join_code);
}

pub fn remove_room(room: OwnedRoom) {
    let mut lock = ROOMS.lock();

    let to_remove = lock
        .iter()
        .filter(|(_, arc)| Arc::ptr_eq(&room, arc))
        .map(|(code, _)| code.clone())
        .next();

    if let Some(code) = to_remove {
        lock.remove(&code);
    }
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

pub fn lock<'a>() -> RoomsLock<'a> {
    ROOMS.lock()
}
