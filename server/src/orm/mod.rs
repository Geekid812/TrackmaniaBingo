pub mod models;
mod schema;

use deadpool_diesel::{
    sqlite::{Manager, Object, Pool},
    InteractError, PoolError, Runtime,
};
use diesel::SqliteConnection;
use once_cell::sync::OnceCell;
use thiserror::Error;

static DB_POOL: OnceCell<Pool> = OnceCell::new();

pub fn start_database(url: &str) {
    let manager = Manager::new(url, Runtime::Tokio1);
    let pool = Pool::builder(manager).max_size(8).build().unwrap();
    DB_POOL.get_or_init(|| pool);
}

async fn pooled_connection() -> Result<Object, PoolError> {
    DB_POOL
        .get()
        .expect("database pool should be initialized")
        .get()
        .await
}

pub async fn execute<F, R>(f: F) -> Result<R, ExecuteError>
where
    F: FnOnce(&mut SqliteConnection) -> R + Send + 'static,
    R: Send + 'static,
{
    Ok(pooled_connection().await?.interact(f).await?)
}

#[derive(Error, Debug)]
pub enum ExecuteError {
    #[error(transparent)]
    PoolError(#[from] PoolError),
    #[error(transparent)]
    InteractError(#[from] InteractError),
}
