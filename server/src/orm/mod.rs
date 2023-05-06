pub mod models;
mod schema;

use diesel::prelude::*;
use diesel::sqlite::SqliteConnection;

pub fn establish_connection(url: &str) -> SqliteConnection {
    SqliteConnection::establish(url).unwrap_or_else(|_| panic!("Error connecting to {}", url))
}