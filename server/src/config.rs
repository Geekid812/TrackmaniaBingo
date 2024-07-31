use chrono::Duration;
use once_cell::sync::Lazy;
use parking_lot::Mutex;
use serde::Deserialize;
use serde_with::DurationSeconds;
use std::{
    collections::HashMap,
    fmt::Display,
    fs::{self},
    io,
    sync::OnceLock,
};
use toml::{map::Map, Value};
use tracing::{debug, error, info, warn};

use crate::datatypes::MatchConfiguration;

static CONFIGURATION_KEYS: OnceLock<Mutex<HashMap<String, ConfigValue>>> = OnceLock::new();

/// Types of configuration values.
#[derive(Debug, Clone)]
pub enum ConfigValue {
    String(String),
    Integer(i64),
    Float(f64),
    Boolean(bool),
}

impl ConfigValue {
    /// Get the string value.
    pub fn string(&self) -> Option<String> {
        if let Self::String(s) = self {
            return Some(s.to_string());
        }

        None
    }

    /// Get the integer value.
    pub fn integer(&self) -> Option<i64> {
        if let Self::Integer(i) = self {
            return Some(*i);
        }

        None
    }

    /// Get the float value.
    pub fn float(&self) -> Option<f64> {
        if let Self::Float(f) = self {
            return Some(*f);
        }

        None
    }

    /// Get the boolean value.
    pub fn boolean(&self) -> Option<bool> {
        if let Self::Boolean(b) = self {
            return Some(*b);
        }

        None
    }
}

impl Display for ConfigValue {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            &ConfigValue::String(ref s) => s.fmt(f),
            &ConfigValue::Integer(i) => i.fmt(f),
            &ConfigValue::Float(ft) => ft.fmt(f),
            &ConfigValue::Boolean(b) => b.fmt(f),
        }
    }
}

impl TryFrom<&toml::Value> for ConfigValue {
    type Error = ();

    fn try_from(value: &toml::Value) -> Result<Self, Self::Error> {
        match value {
            Value::String(s) => Ok(ConfigValue::String(s.to_string())),
            Value::Integer(i) => Ok(ConfigValue::Integer(*i)),
            Value::Float(f) => Ok(ConfigValue::Float(*f)),
            Value::Boolean(b) => Ok(ConfigValue::Boolean(*b)),
            _ => Err(()),
        }
    }
}

fn populate_configuration_keys(
    map: &mut HashMap<String, ConfigValue>,
    table: &Map<String, Value>,
    prefix: String,
) {
    for (key, val) in table.iter() {
        if let Ok(value) = ConfigValue::try_from(val) {
            map.insert(prefix.clone() + key, value);
            continue;
        }

        if let Some(table) = val.as_table() {
            populate_configuration_keys(map, table, prefix.clone() + key + ".");
            continue;
        }

        warn!(
            "unknown type for configuration key: {}{} = {}",
            prefix.clone(),
            key,
            val
        );
    }
}

/// Initialize configuration. Only call this once.
pub fn initialize() -> bool {
    let default_data = include_str!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/data/config.default.toml"
    ));

    info!("intializing configuration");
    let mut configuration = HashMap::new();

    let default_config: Map<String, Value> =
        toml::from_str(default_data).expect("default configuration has invalid syntax");
    populate_configuration_keys(&mut configuration, &default_config, String::new());

    match fs::read_to_string("config.toml") {
        Ok(text) => {
            let config_overrides: Map<String, Value> = match toml::from_str(&text) {
                Ok(map) => map,
                Err(e) => {
                    error!("error loading configuration file: {e}");
                    return false;
                }
            };
            populate_configuration_keys(&mut configuration, &config_overrides, String::new());
        }
        Err(ref e) if e.kind() == io::ErrorKind::NotFound => {
            info!("configuration file not found, created a new copy of the default configuration.");
            fs::write("config.toml", default_data).unwrap();
        }
        Err(e) => {
            error!("IO error reading configuration file: {e}");
            return false;
        }
    };

    CONFIGURATION_KEYS
        .set(Mutex::new(configuration))
        .expect("config::initialize called more than once");
    return true;
}

/// Get the value of a configuration setting.
pub fn get(key: &str) -> Option<ConfigValue> {
    let configuration = CONFIGURATION_KEYS.get().unwrap().lock();
    configuration.get(key).map(Clone::clone)
}

/// Get the string value of a configuration setting.
pub fn get_string(key: &str) -> Option<String> {
    let configuration = CONFIGURATION_KEYS.get().unwrap().lock();
    configuration.get(key).and_then(|value| value.string())
}

/// Get the integer value of a configuration setting.
pub fn get_integer(key: &str) -> Option<i64> {
    let configuration = CONFIGURATION_KEYS.get().unwrap().lock();
    configuration.get(key).and_then(|value| value.integer())
}

/// Get the float value of a configuration setting.
pub fn get_float(key: &str) -> Option<f64> {
    let configuration = CONFIGURATION_KEYS.get().unwrap().lock();
    configuration.get(key).and_then(|value| value.float())
}

/// Get the boolean value of a configuration setting.
pub fn get_boolean(key: &str) -> Option<bool> {
    let configuration = CONFIGURATION_KEYS.get().unwrap().lock();
    configuration.get(key).and_then(|value| value.boolean())
}

/// Print all configuration keys in alphabetical order for debugging.
pub fn enumerate_keys() {
    let configuration = CONFIGURATION_KEYS.get().unwrap().lock();
    let mut keys: Vec<&String> = configuration.keys().collect();
    keys.sort_unstable();

    for k in keys.into_iter() {
        debug!("{}: {}", k, configuration.get(k).unwrap());
    }
}

/// Return whether the current environment has development status enabled.
pub fn is_development() -> bool {
    get_string("environment").is_some_and(|v| v == "dev")
}
