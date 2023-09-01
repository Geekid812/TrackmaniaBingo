use std::pin::Pin;

use diesel::{ExpressionMethods, QueryDsl, RunQueryDsl};
use futures::Future;
use once_cell::sync::Lazy;
use tracing::error;

use crate::config::CONFIG;
use crate::core::room::GameRoom;
use crate::integrations::tmexchange::MappackLoader;
use crate::orm::dsl::RandomDsl;
use crate::{
    core::{directory::Shared, livegame::MatchConfiguration, models::livegame::MapMode},
    orm::mapcache::{self, record::MapRecord},
};

type MaploadResult = Result<Vec<MapRecord>, anyhow::Error>;
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
    match config.selection {
        MapMode::RandomTMX => Box::pin(cache_load_mxrandom(config.grid_size * config.grid_size)),
        MapMode::Mappack => Box::pin(network_load_mappack(config.mappack_id.unwrap())),
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
            error!("{}", e);
        }
    }
}

async fn cache_load_mxrandom(count: usize) -> Result<Vec<MapRecord>, anyhow::Error> {
    mapcache::execute(move |conn| {
        use crate::orm::mapcache::schema::maps::dsl::*;

        maps.filter(author_time.le(CONFIG.game.mxrandom_max_author_time.num_milliseconds() as i32))
            .randomize(count as i32)
            .load::<MapRecord>(conn)
    })
    .await
    .expect("database execute error")
    .map_err(anyhow::Error::from)
}

async fn network_load_mappack(mappack_id: u32) -> Result<Vec<MapRecord>, anyhow::Error> {
    MAPPACK_LOADER
        .get_mappack_tracks(&mappack_id.to_string())
        .await
}
