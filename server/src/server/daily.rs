use chrono::{Duration, Utc};
use parking_lot::Mutex;
use tracing::{error, info};

use crate::{
    config::CONFIG,
    core::{directory::Owned, livegame::LiveMatch},
};

use super::mapload;

static DAILY_MATCH: Mutex<Option<Owned<LiveMatch>>> = Mutex::new(None);

pub async fn start_daily_challenge() {
    let config = CONFIG
        .game
        .daily_config
        .clone()
        .expect("no daily config provided");
    let maps = mapload::gather_maps(&config).await;
    if let Err(e) = maps {
        error!("daily challenge not started: {}", e);
        return;
    }
    let maps = maps.unwrap();
    let date = Utc::now();
    let live_match = LiveMatch::new(config, maps, Vec::new());

    {
        let mut game = live_match.lock();
        game.set_start_countdown(Duration::zero());
        game.setup_match_start(date.clone());
    }

    *DAILY_MATCH.lock() = Some(live_match);
    info!("new daily challenge started at {}", date);
}
