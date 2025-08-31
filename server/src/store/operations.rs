// Allow ununsed functions here since this is an internal database API
#![allow(dead_code)]

use sqlx::{
    query::Query,
    sqlite::{SqliteArguments, SqliteQueryResult, SqliteRow},
    Sqlite, SqlitePool,
};
use tracing::error;

/// Execute an SQL query.
pub async fn execute(connection: &SqlitePool, sql: &str) -> Result<SqliteQueryResult, sqlx::Error> {
    sqlx::query(sql)
        .execute(connection)
        .await
        .inspect_err(|e| error!("error running SQL query: {e}"))
}

/// Execute an SQL query with bound parameters.
pub async fn execute_with_arguments<'q>(
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
pub async fn query(connection: &SqlitePool, sql: &str) -> Result<SqliteRow, sqlx::Error> {
    sqlx::query(sql)
        .fetch_one(connection)
        .await
        .inspect_err(|e| error!("error running SQL query: {e}"))
}

/// Execute an SQL query with bound parameters.
pub async fn query_with_arguments<'q>(
    connection: &SqlitePool,
    sql: &'q str,
    arguments: impl FnOnce(
        Query<'q, Sqlite, SqliteArguments<'q>>,
    ) -> Query<'q, Sqlite, SqliteArguments<'q>>,
) -> Result<SqliteRow, sqlx::Error> {
    let mut query = sqlx::query(sql);
    query = arguments(query);
    query
        .fetch_one(connection)
        .await
        .inspect_err(|e| error!("error running SQL query: {e}"))
}

/// Execute an SQL query.
pub async fn query_all(connection: &SqlitePool, sql: &str) -> Result<Vec<SqliteRow>, sqlx::Error> {
    sqlx::query(sql)
        .fetch_all(connection)
        .await
        .inspect_err(|e| error!("error running SQL query: {e}"))
}

/// Execute an SQL query with bound parameters.
pub async fn query_all_with_arguments<'q>(
    connection: &SqlitePool,
    sql: &'q str,
    arguments: impl FnOnce(
        Query<'q, Sqlite, SqliteArguments<'q>>,
    ) -> Query<'q, Sqlite, SqliteArguments<'q>>,
) -> Result<Vec<SqliteRow>, sqlx::Error> {
    let mut query = sqlx::query(sql);
    query = arguments(query);
    query
        .fetch_all(connection)
        .await
        .inspect_err(|e| error!("error running SQL query: {e}"))
}

/// Type-erased query function, same as `execute`.
pub async fn chained_query(connection: &SqlitePool, sql: &str) -> Result<(), ()> {
    execute(connection, sql).await.map(|_| ()).map_err(|_| ())
}
