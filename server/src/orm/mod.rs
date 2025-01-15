pub mod mapcache;

use once_cell::sync::OnceCell;
use sqlx::{
    database::HasArguments,
    sqlite::{SqlitePoolOptions, SqliteRow},
    Sqlite, SqlitePool,
};

static DB_POOL: OnceCell<SqlitePool> = OnceCell::new();
pub type Connection = sqlx::pool::PoolConnection<Sqlite>;
pub type Row = SqliteRow;
pub type Query<'a> = sqlx::query::Query<'a, Sqlite, <Sqlite as HasArguments<'a>>::Arguments>;

pub async fn start_database(url: &str) {
    let pool = SqlitePoolOptions::new()
        .max_connections(5)
        .connect(url)
        .await
        .expect("database should be started");
    DB_POOL.get_or_init(|| pool);
}

pub async fn execute<F, R>(f: F) -> R
where
    F: FnOnce(Connection) -> R + Send + 'static,
    R: Send + 'static,
{
    f(DB_POOL
        .get()
        .expect("database not initialized")
        .acquire()
        .await
        .expect("did not acquire database connection"))
}
