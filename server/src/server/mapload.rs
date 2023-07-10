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

static MAPPACK_LOADER: Lazy<MappackLoader> = Lazy::new(|| MappackLoader::new());

pub fn load_maps(room: Shared<GameRoom>, config: MatchConfiguration, userdata: u32) {
    match config.selection {
        MapMode::RandomTMX => tokio::spawn(fetch_and_load(
            room,
            cache_load_mxrandom(config.grid_size * config.grid_size),
            userdata,
        )),
        MapMode::Mappack => tokio::spawn(fetch_and_load(
            room,
            network_load_mappack(config.mappack_id.unwrap()),
            userdata,
        )),
        _ => unimplemented!(),
    };
}

async fn fetch_and_load<F: Future<Output = Result<Vec<MapRecord>, anyhow::Error>>>(
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
