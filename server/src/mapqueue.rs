use anyhow::anyhow;
use futures::Future;
use once_cell::sync::Lazy;
use parking_lot::{Mutex, MutexGuard};
use reqwest::{
    header::{HeaderMap, HeaderValue},
    Client, ClientBuilder, Url,
};
use tokio::join;
use tracing::{debug, error, warn};

use crate::{
    config,
    gamemap::GameMap,
    gameroom::MapMode,
    rest::tmexchange::{self as tmxapi, MapError},
};

static MXRANDOM_MAP_QUEUE: Mutex<Lazy<Vec<GameMap>>> =
    Mutex::new(Lazy::new(|| Vec::with_capacity(config::MAP_QUEUE_CAPACITY)));
static TOTD_MAP_QUEUE: Mutex<Lazy<Vec<GameMap>>> =
    Mutex::new(Lazy::new(|| Vec::with_capacity(config::MAP_QUEUE_CAPACITY)));
static CLIENT: Lazy<Client> = Lazy::new(load_tmx_client);

fn load_tmx_client() -> Client {
    let mut headers = HeaderMap::new();
    headers.insert(
        "user-agent",
        HeaderValue::from_static(config::TMX_USERAGENT),
    );

    ClientBuilder::new()
        .timeout(config::TMX_FETCH_TIMEOUT)
        .default_headers(headers)
        .build()
        .expect("tmx client to be built")
}

fn get_tracks_inner<'a>(
    count: usize,
    mut lock: MutexGuard<'a, Lazy<Vec<GameMap>>>,
) -> Result<Vec<GameMap>, anyhow::Error> {
    let length = lock.len();
    if length < count {
        return Err(anyhow!("could not load enough maps from TrackmaniaExchange, it could be offline or unavailable. Try again in a few minutes."));
    }
    Ok(lock.split_off(length - count))
}

fn pushback_tracks_inner<'a>(maps: Vec<GameMap>, mut lock: MutexGuard<'a, Lazy<Vec<GameMap>>>) {
    lock.extend(maps)
}

pub fn get_tracks(mode: MapMode, count: usize) -> Result<Vec<GameMap>, anyhow::Error> {
    match mode {
        MapMode::TOTD => get_tracks_inner(count, TOTD_MAP_QUEUE.lock()),
        MapMode::RandomTMX => get_tracks_inner(count, MXRANDOM_MAP_QUEUE.lock()),
        MapMode::Mappack => Err(anyhow!(
            "invalid map mode selected. This should not happen!"
        )),
    }
}

pub fn pushback_tracks(mode: MapMode, maps: Vec<GameMap>) {
    match mode {
        MapMode::TOTD => pushback_tracks_inner(maps, TOTD_MAP_QUEUE.lock()),
        MapMode::RandomTMX => pushback_tracks_inner(maps, MXRANDOM_MAP_QUEUE.lock()),
        MapMode::Mappack => {
            error!("pushback_tracks called with Mappack mapmode");
        }
    }
}

pub async fn get_mappack_tracks(
    mappack_id: u32,
    count: usize,
) -> Result<Vec<GameMap>, anyhow::Error> {
    let mut maps = tmxapi::get_mappack_tracks(&CLIENT, mappack_id).await?;
    if maps.len() < count {
        return Err(anyhow!(
            "not enough tracks in the mappack: expected {} tracks, got {}",
            count,
            maps.len()
        ));
    }
    maps.truncate(count);
    Ok(maps)
}

async fn queue_loop<F, Fut>(queue: &Mutex<Lazy<Vec<GameMap>>>, fetch_callback: F)
where
    F: Fn(&'static Client) -> Fut,
    Fut: Future<Output = Result<GameMap, MapError>>,
{
    loop {
        if queue.lock().len() < config::MAP_QUEUE_CAPACITY {
            match fetch_callback(&CLIENT).await {
                Ok(map) => {
                    let mut lock = queue.lock();
                    if lock.iter().find(|m| m.uid == map.uid).is_none() {
                        debug!("enqueued: {}", map.name);
                        lock.push(map);
                    }
                }
                Err(e) => match e {
                    tmxapi::MapError::Rejected(_) => debug!("map rejected from queue"),
                    tmxapi::MapError::Request(e) => warn!(
                        "TMX api fetch error: {} {:?}",
                        e.url().map(Url::to_string).unwrap_or("(None)".to_string()),
                        e
                    ),
                },
            }
        }
        tokio::time::sleep(config::FETCH_INTERVAL).await;
    }
}

pub async fn run_loop() {
    join!(
        queue_loop(&TOTD_MAP_QUEUE, tmxapi::get_totd),
        queue_loop(&MXRANDOM_MAP_QUEUE, tmxapi::get_randomtmx)
    );
}
