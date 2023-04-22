use futures::{Future, FutureExt};
use parking_lot::MutexGuard;
use serde::Serialize;
use std::sync::Arc;
use tokio::spawn;

use crate::{
    gameroom::{GameRoom, MapMode},
    mapqueue,
    roomlist::{OwnedRoom, SharedRoom},
};

#[derive(Serialize, Clone, Debug)]
pub struct GameMap {
    pub track_id: i64,
    pub uid: String,
    pub name: String,
    pub author_name: String,
}

pub async fn load_maps(
    count: usize,
    mode: MapMode,
    mappack_id: Option<u32>,
) -> Result<Vec<GameMap>, anyhow::Error> {
    if let Some(id) = mappack_id {
        return mapqueue::get_mappack_tracks(id, count).await;
    }

    mapqueue::get_tracks(mode, count)
}

async fn delayed_load<F>(room: SharedRoom, fut: F)
where
    F: Future<Output = Result<Vec<GameMap>, anyhow::Error>>,
{
    match fut.await {
        Ok(maps) => (),
        Err(e) => (),
    }
}

pub fn init_maps<'a>(
    room: &OwnedRoom,
    lock: &'a mut MutexGuard<GameRoom>,
) -> Option<anyhow::Error> {
    let config = lock.config();
    let map_count = (config.grid_size * config.grid_size) as usize - lock.maps().len();
    let load_fut = load_maps(map_count, config.selection, config.mappack_id);
    let mut pinned = Box::pin(load_fut);

    if let Some(result) = pinned.as_mut().now_or_never() {
        match result {
            Ok(maps) => lock.add_maps(maps),
            Err(e) => return Some(e),
        };
    } else {
        spawn(delayed_load(Arc::downgrade(&room), pinned));
    }
    None
}
