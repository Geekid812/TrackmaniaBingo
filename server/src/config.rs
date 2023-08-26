use chrono::Duration;
use once_cell::sync::Lazy;
use serde::Deserialize;
use serde_with::DurationSeconds;
use std::collections::HashMap;

pub static CONFIG: Lazy<Config> = Lazy::new(|| {
    let toml_content = std::fs::read_to_string("config.toml");
    toml_content
        .map(|s| toml::from_str(&s).expect("config file parsing error"))
        .unwrap_or_default()
});

#[derive(Deserialize)]
#[serde(default)]
pub struct Config {
    pub log_level: String,
    pub database_url: String,
    pub mapcache_url: String,
    pub tcp_port: u16,
    pub min_client: Option<String>,
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
pub struct GameConfig {
    pub teams: HashMap<String, String>,
    #[serde_as(as = "DurationSeconds<i64>")]
    pub mxrandom_max_author_time: Duration,
    #[serde_as(as = "DurationSeconds<i64>")]
    pub start_countdown: Duration,
}

#[derive(Deserialize)]
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
            tcp_port: 3080,
            min_client: None,
            tmx_useragent: "TrackmaniaBingo (development)".to_string(),
            secrets: Secrets {
                openplanet_auth: None,
                admin_key: None,
            },
            mapqueue: MapsConfig {
                queue_size: 10,
                queue_capacity: 30,
                fetch_timeout: Duration::seconds(20),
                fetch_interval: Duration::seconds(4),
            },
            game: GameConfig {
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
            },
            routes: RestConfig {
                openplanet: OpenplanetRoutes {
                    base: "https://openplanet.dev".to_owned(),
                    auth_validate: "/api/auth/validate".to_owned(),
                },
                tmx: TmxRoutes {
                    base: "https://trackmania.exchange".to_owned(),
                    map_search: "/mapsearch2/search".to_owned(),
                    mappack_maps: "/api/mappack/get_mappack_tracks/".to_owned(),
                },
            },
        }
    }
}
