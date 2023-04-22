use std::time::Duration;

use crate::util::version::Version;
use tracing::Level;

pub const LOG_LEVEL: Level = Level::DEBUG;
pub const TCP_LISTENING_PORT: u16 = 8040;
pub const MINIMUM_CLIENT_VERSION: Version = Version(4, 0);

pub const MAP_QUEUE_SIZE: usize = 10;
pub const MAP_QUEUE_CAPACITY: usize = 30;
pub const TMX_FETCH_TIMEOUT: Duration = Duration::from_secs(20);
pub const FETCH_INTERVAL: Duration = Duration::from_secs(4);

pub const AUTHENTICATION_API_SECRET: Option<&'static str> = option_env!("AUTH_SECRET");
pub const TMX_USERAGENT: &'static str = env!("TMX_USERAGENT");
pub const ADMIN_KEY: Option<&'static str> = option_env!("ADMIN_KEY");

pub const TEAMS: [(&'static str, &'static str); 6] = [
    ("Red", "F81315"),
    ("Green", "8BC34A"),
    ("Blue", "0095FF"),
    ("Cyan", "4DD0E1"),
    ("Pink", "E04980"),
    ("Yellow", "FFFF00"),
];

pub const JOINCODE_LENGTH: u32 = 6;
pub const JOINCODE_CHARS: [char; 10] = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];

pub const MAXIMUM_PACKET_SIZE: i32 = 2048;

pub const MXRANDOM_MAX_AUTHOR_TIME: i32 = Duration::from_secs(5 * 60).as_millis() as i32;

pub mod routes {
    pub mod openplanet {
        pub const BASE: &'static str = "https://openplanet.dev";

        pub const AUTH_VALIDATE: &'static str = "/api/auth/validate";
    }

    pub mod tmexchange {
        pub const BASE: &'static str = "https://trackmania.exchange";

        pub const MAP_SEARCH: &'static str = "/mapsearch2/search";
        pub const MAPPACK_MAPS: &'static str = "/api/mappack/get_mappack_tracks/";
    }
}
