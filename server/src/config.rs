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

pub static CONFIG: Lazy<Config> = Lazy::new(|| {
    let toml_content = std::fs::read_to_string("config.toml");
    toml_content
        .map(|s| toml::from_str(&s).expect("config file parsing error"))
        .unwrap_or_default()
});

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

#[derive(Deserialize)]
#[serde(default)]
pub struct Config {
    pub log_level: String,
    pub database_url: String,
    pub mapcache_url: String,
    pub min_client: String,
    pub tmx_useragent: String,
    pub secrets: Secrets,
    pub mapqueue: MapsConfig,
    pub game: GameConfig,
    pub routes: RestConfig,
}

#[derive(Deserialize)]
pub struct Secrets {
    pub openplanet_auth: Option<String>,
    pub admin_key: Option<String>,
}

#[serde_with::serde_as]
#[derive(Deserialize)]
#[serde(default)]
pub struct MapsConfig {
    pub queue_size: usize,
    pub queue_capacity: usize,
    #[serde_as(as = "DurationSeconds<i64>")]
    pub fetch_timeout: Duration,
    #[serde_as(as = "DurationSeconds<i64>")]
    pub fetch_interval: Duration,
}

#[serde_with::serde_as]
#[derive(Deserialize)]
#[serde(default)]
pub struct GameConfig {
    pub teams: HashMap<String, String>,
    #[serde_as(as = "DurationSeconds<i64>")]
    pub mxrandom_max_author_time: Duration,
    #[serde_as(as = "DurationSeconds<i64>")]
    pub start_countdown: Duration,
    pub daily_config: Option<MatchConfiguration>,
    pub daily_reset: DailyResetConfig,
}

#[serde_with::serde_as]
#[derive(Deserialize, Default)]
#[serde(default)]
pub struct DailyResetConfig {
    pub hour: u32,
    pub minute: u32,
}

#[derive(Deserialize)]
#[serde(default)]
pub struct RestConfig {
    pub openplanet: OpenplanetRoutes,
    pub tmx: TmxRoutes,
}

#[derive(Deserialize)]
pub struct OpenplanetRoutes {
    pub base: String,
    pub auth_validate: String,
}

#[derive(Deserialize)]
pub struct TmxRoutes {
    pub base: String,
    pub map_search: String,
    pub mappack_maps: String,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            log_level: "INFO".to_owned(),
            database_url: "sqlite://db/main.db".to_owned(),
            mapcache_url: "sqlite://mapcache.db".to_owned(),
            min_client: "4.0".to_owned(),
            tmx_useragent: "TrackmaniaBingo (development)".to_string(),
            secrets: Secrets {
                openplanet_auth: None,
                admin_key: None,
            },
            mapqueue: MapsConfig::default(),
            game: GameConfig::default(),
            routes: RestConfig::default(),
        }
    }
}

impl Default for MapsConfig {
    fn default() -> Self {
        MapsConfig {
            queue_size: 10,
            queue_capacity: 30,
            fetch_timeout: Duration::seconds(20),
            fetch_interval: Duration::seconds(4),
        }
    }
}

impl Default for GameConfig {
    fn default() -> Self {
        GameConfig {
            teams: HashMap::from_iter(
                vec![
                    ("Red", "F81315"),
                    ("Green", "8BC34A"),
                    ("Blue", "0095FF"),
                    ("Cyan", "4DD0E1"),
                    ("Pink", "E04980"),
                    ("Yellow", "FFFF00"),
                ]
                .into_iter()
                .map(|(s1, s2)| (s1.to_owned(), s2.to_owned())),
            ),
            mxrandom_max_author_time: Duration::minutes(5),
            start_countdown: Duration::seconds(5),
            daily_config: None,
            daily_reset: DailyResetConfig::default(),
        }
    }
}

impl Default for RestConfig {
    fn default() -> Self {
        RestConfig {
            openplanet: OpenplanetRoutes {
                base: "https://openplanet.dev".to_owned(),
                auth_validate: "/api/auth/validate".to_owned(),
            },
            tmx: TmxRoutes {
                base: "https://trackmania.exchange".to_owned(),
                map_search: "/mapsearch2/search".to_owned(),
                mappack_maps: "/api/mappack/get_mappack_tracks/".to_owned(),
            },
        }
    }
}
