use chrono::{Duration, Timelike, Utc};
use parking_lot::Mutex;
use tokio::time::Duration as TokioDuration;
use tokio::time::{sleep_until, Instant};
use tracing::{error, info};

use crate::{
    config::CONFIG,
    core::{directory::Owned, livegame::LiveMatch},
};

use super::mapload;

pub static DAILY_MATCH: Mutex<Option<Owned<LiveMatch>>> = Mutex::new(None);

async fn start_daily_challenge() {
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

pub async fn run_loop() {
    loop {
        let now = Utc::now();
        let midnight = now
            .with_hour(0)
            .unwrap()
            .with_minute(0)
            .unwrap()
            .with_second(0)
            .unwrap();
        let tomorrow = midnight + Duration::days(1);
        let time_until_midnight = TokioDuration::from((tomorrow - now).to_std().unwrap());
        sleep_until(Instant::now() + time_until_midnight).await;
        start_daily_challenge().await;
    }
}
