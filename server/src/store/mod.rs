use std::{collections::HashMap, fs, path::Path};

use sqlx::{
    query::Query,
    sqlite::{SqliteArguments, SqlitePoolOptions, SqliteQueryResult, SqliteRow},
    Row, Sqlite, SqlitePool,
};
use tracing::{error, info};

static DATABASE_VERSIONS: [&'static str; 1] = [include_str!(concat!(
    env!("CARGO_MANIFEST_DIR"),
    "/db/versions/v1.sql"
))];

/// Creates an empty file if the path specified doesn't exist.
fn file_create(path: &str) {
    if let Ok(false) = Path::new(path).try_exists() {
        info!("file '{path}' does not exist, creating it.");
        fs::write(path, &[]).expect("error creating new file");
    }
}

/// Execute an SQL query.
async fn execute(connection: &SqlitePool, sql: &str) -> Result<SqliteQueryResult, sqlx::Error> {
    sqlx::query(sql)
        .execute(connection)
        .await
        .inspect_err(|e| error!("error running SQL query: {e}"))
}

/// Execute an SQL query with bound parameters.
async fn execute_with_arguments<'q>(
    connection: &SqlitePool,
    sql: &'q str,
    arguments: impl FnOnce(
        Query<'q, Sqlite, SqliteArguments<'q>>,
    ) -> Query<'q, Sqlite, SqliteArguments<'q>>,
) -> Result<SqliteQueryResult, sqlx::Error> {
    let mut query = sqlx::query(sql);
    query = arguments(query);
    query
        .execute(connection)
        .await
        .inspect_err(|e| error!("error running SQL query: {e}"))
}

/// Execute an SQL query.
async fn query_all(connection: &SqlitePool, sql: &str) -> Result<Vec<SqliteRow>, sqlx::Error> {
    sqlx::query(sql)
        .fetch_all(connection)
        .await
        .inspect_err(|e| error!("error running SQL query: {e}"))
}

/// Type-erased query function, same as `execute`.
async fn chained_query(connection: &SqlitePool, sql: &str) -> Result<(), ()> {
    execute(connection, sql).await.map(|_| ()).map_err(|_| ())
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
