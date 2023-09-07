use once_cell::sync::OnceCell;
use sqlx::{sqlite::SqlitePoolOptions, SqlitePool};

use super::Connection;

pub mod record;

static MAPCACHE_POOL: OnceCell<SqlitePool> = OnceCell::new();

pub async fn start_database(url: &str) {
    let pool = SqlitePoolOptions::new()
        .max_connections(3)
        .connect(url)
        .await
        .expect("database should be started");
    MAPCACHE_POOL.get_or_init(|| pool);
}

pub async fn execute<F, R>(f: F) -> R
where
    F: FnOnce(Connection) -> R + Send + 'static,
    R: Send + 'static,
{
    f(MAPCACHE_POOL
        .get()
        .expect("database not initialized")
        .acquire()
        .await
        .expect("did not acquire database connection"))
}
