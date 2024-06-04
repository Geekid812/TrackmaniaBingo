use std::{collections::HashMap, fs, path::Path, sync::OnceLock};

use sqlx::{sqlite::SqlitePoolOptions, Row, SqlitePool};
use tracing::{error, info};

static DATABASE_VERSIONS: [&'static str; 2] = [
    include_str!(concat!(env!("CARGO_MANIFEST_DIR"), "/db/versions/v1.sql")),
    include_str!(concat!(env!("CARGO_MANIFEST_DIR"), "/db/versions/v2.sql")),
];

static PRIMARY_STORE: OnceLock<SqlitePool> = OnceLock::new();

mod operations;
pub mod player;

use operations::*;

pub type StoreReadResult<V> = Result<V, sqlx::Error>;
pub type StoreWriteResult = Result<(), sqlx::Error>;

/// Creates an empty file if the path specified doesn't exist.
fn file_create(path: &str) {
    if let Ok(false) = Path::new(path).try_exists() {
        info!("file '{path}' does not exist, creating it.");
        fs::write(path, &[]).expect("error creating new file");
    }
}

/// Initialize the primary database. Only call this once.
pub async fn initialize_primary_store(path: &str) {
    file_create(path);

    let connection_pool = SqlitePoolOptions::new()
        .max_connections(5)
        .connect(path)
        .await
        .expect("primary store did not start");

    let configuration = match get_master_configuration(&connection_pool).await {
        Ok(config) => config,
        Err(_) => return,
    };

    apply_database_updates(&connection_pool, &configuration).await;
    PRIMARY_STORE.get_or_init(|| connection_pool);
}

/// Run SQL migrations to update the database to the latest version.
async fn apply_database_updates(pool: &SqlitePool, configuration: &HashMap<String, String>) {
    let mut version: usize = match configuration
        .get("version")
        .and_then(|value_str| value_str.parse().ok())
    {
        Some(v) => v,
        None => {
            error!("database configuration table does not a valid 'version' key");
            return;
        }
    };

    let latest_version = DATABASE_VERSIONS.len();
    while version < latest_version {
        version += 1;
        if !apply_version_update(pool, version).await {
            error!("an error occured applying database updates, aborting");
            return;
        };
    }
}

/// Apply a migration to upgrade from version (v - 1) to version v.
async fn apply_version_update(pool: &SqlitePool, v: usize) -> bool {
    info!(
        "applying update from schema version {} to version {}",
        v - 1,
        v
    );

    let sql_query = DATABASE_VERSIONS[v - 1];
    execute(&pool, sql_query).await.is_ok() && set_database_version(pool, v).await
}

/// Set the database version value.
async fn set_database_version(pool: &SqlitePool, v: usize) -> bool {
    execute_with_arguments(
        pool,
        "UPDATE master SET value = ? WHERE key = 'version'",
        |query| query.bind(v as i32),
    )
    .await
    .is_ok()
}

/// Retreive all key-value pairs in the database configuration table.
async fn get_master_configuration(pool: &SqlitePool) -> Result<HashMap<String, String>, ()> {
    chained_query(
        pool,
        "CREATE TABLE IF NOT EXISTS master ( key TEXT UNIQUE, value TEXT );",
    )
    .await?;

    // Insert default configuration for new database
    chained_query(pool, "INSERT OR IGNORE INTO master VALUES ('version', 0);").await?;

    let rows_iter = query_all(pool, "SELECT key, value FROM master;")
        .await
        .map_err(|_| ())?
        .into_iter()
        .map(|row| (row.get(0), row.get(1)));
    let master_config: HashMap<String, String> = HashMap::from_iter(rows_iter);

    Ok(master_config)
}

/// Get a handle to the connection pool. Panics if it has not been initialized.
fn get_store() -> &'static SqlitePool {
    PRIMARY_STORE.get().expect("store not initialized")
}
