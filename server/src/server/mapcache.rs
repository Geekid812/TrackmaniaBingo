use diesel::{ExpressionMethods, QueryDsl, RunQueryDsl};
use futures::Future;
use tracing::error;

use crate::config::CONFIG;
use crate::core::room::GameRoom;
use crate::orm::dsl::RandomDsl;
use crate::{
    core::{directory::Shared, livegame::MatchConfiguration, models::livegame::MapMode},
    orm::mapcache::{self, record::MapRecord},
};

pub fn load_maps(room: Shared<GameRoom>, config: MatchConfiguration, userdata: u32) {
    let fut = match config.selection {
        MapMode::RandomTMX => {
            cache_load_mxrandom(config.grid_size as usize * config.grid_size as usize)
        }
        _ => unimplemented!(),
    };
    tokio::spawn(fetch_and_load(room, fut, userdata));
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

        maps.filter(author_time.le(CONFIG.game.mxrandom_max_author_time.as_millis() as i32))
            .randomize(count as i32)
            .load::<MapRecord>(conn)
    })
    .await
    .expect("database execute error")
    .map_err(anyhow::Error::from)
}
