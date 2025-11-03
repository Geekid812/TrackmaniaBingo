use std::pin::Pin;

use futures::executor::block_on;
use futures::Future;
use once_cell::sync::Lazy;
use sqlx::FromRow;
use tracing::error;

use crate::config;
use crate::core::models::map::GameMap;
use crate::core::room::GameRoom;
use crate::datatypes::{Gamemode, MapMode, MatchConfiguration};
use crate::integrations::tmexchange::MappackLoader;
use crate::{
    core::directory::Shared,
    orm::mapcache::{self, record::MapRecord},
};

type MaploadResult = Result<Vec<GameMap>, anyhow::Error>;
static MAPPACK_LOADER: Lazy<MappackLoader> = Lazy::new(|| MappackLoader::new());

pub fn load_maps(room: Shared<GameRoom>, config: &MatchConfiguration, userdata: u32) {
    let fut = get_load_future(config);
    tokio::spawn(fetch_and_load(room, fut, userdata));
}

pub async fn gather_maps(config: &MatchConfiguration) -> MaploadResult {
    get_load_future(config).await
}

fn get_load_future(
    config: &MatchConfiguration,
) -> Pin<Box<dyn Future<Output = MaploadResult> + Send>> {
    let mut reroll_multiplier = 1;
    if config.rerolls || config.mode == Gamemode::Frenzy {
        reroll_multiplier = 2;
    }

    match config.selection {
        MapMode::RandomTMX => Box::pin(cache_load_mxrandom(
            config.grid_size * config.grid_size * reroll_multiplier,
        )),
        MapMode::Tags => Box::pin(cache_load_tag(
            config.grid_size * config.grid_size * reroll_multiplier,
            config.map_tag.unwrap(),
        )),
        MapMode::Mappack => Box::pin(network_load_mappack(config.mappack_id.unwrap())),
        #[allow(unreachable_patterns)]
        _ => unimplemented!(),
    }
}

async fn fetch_and_load<F: Future<Output = MaploadResult>>(
    room: Shared<GameRoom>,
    fut: F,
    userdata: u32,
) {
    match fut.await {
        Ok(maps) => {
            if let Some(room) = room.upgrade() {
                room.lock().maps_load_callback(maps, userdata);
            }
        }
        Err(e) => {
            error!("maps loading error: {}", e);
        }
    }
}

async fn cache_load_mxrandom(count: u32) -> MaploadResult {
    mapcache::execute(move |mut conn| {
        let query =
            sqlx::query("SELECT * FROM maps WHERE tmxid IN (SELECT tmxid FROM maps WHERE author_time <= ? ORDER BY RANDOM() LIMIT ?)")
                .bind(config::get_integer("maps.max_author_millis").unwrap_or(180000))
                .bind(count as i32);
        block_on(query.fetch_all(&mut *conn)).map(|v| {
            v.iter()
                .map(|r| GameMap::TMX(MapRecord::from_row(r).expect("MapRecord from_row failed")))
                .collect()
        })
    })
    .await
    .map_err(anyhow::Error::from)
}

async fn cache_load_tag(count: u32, tag: i32) -> MaploadResult {
    mapcache::execute(move |mut conn| {
        let query =
            sqlx::query("SELECT * FROM maps WHERE tmxid IN (SELECT tmxid FROM maps WHERE author_time <= ? AND (tags = ? OR tags LIKE ? + ',%') ORDER BY RANDOM() LIMIT ?)")
                .bind(config::get_integer("maps.max_author_millis").unwrap_or(180000))
                .bind(tag)
                .bind(tag)
                .bind(count as i32);
        block_on(query.fetch_all(&mut *conn)).map(|v| {
            v.iter()
            .map(|r| GameMap::TMX(MapRecord::from_row(r).expect("MapRecord from_row failed")))
            .collect()
        })
    })
    .await
    .map_err(anyhow::Error::from)
}

async fn network_load_mappack(mappack_id: u32) -> MaploadResult {
    MAPPACK_LOADER
        .get_mappack_tracks(&mappack_id.to_string())
        .await
}
