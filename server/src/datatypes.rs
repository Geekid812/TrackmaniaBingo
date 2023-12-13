// This file is automatically @generated by the `typegen` tool.
// Do not manually edit it! See `common/types.xml` for details.
use chrono::{DateTime, Duration, Utc};
use derivative::Derivative;
use serde::{Deserialize, Serialize};
use serde_repr::{Deserialize_repr, Serialize_repr};
use serde_with::{serde_as, DurationMilliSeconds, TimestampSeconds};

/* A simple reference to a registered player. */
#[serde_as]
#[derive(Serialize, Deserialize, Debug, Clone, Derivative)]
#[derivative(Default)]
pub struct PlayerRef {
    pub uid: u32,
    pub name: String,
}

/* Room parameters set by the host. */
#[serde_as]
#[derive(Serialize, Deserialize, Debug, Clone, Derivative)]
#[derivative(Default)]
pub struct RoomConfiguration {
    pub name: String,
    pub public: bool,
    pub randomize: bool,
    pub size: u32,
}

/* Match parameters set by the host. */
#[serde_as]
#[derive(Serialize, Deserialize, Debug, Clone, Derivative)]
#[derivative(Default)]
pub struct MatchConfiguration {
    #[derivative(Default(value = "5"))]
	pub grid_size: u32,
    #[derivative(Default(value = "MapMode::RandomTMX"))]
	pub selection: MapMode,
    #[derivative(Default(value = "Medal::Author"))]
	pub target_medal: Medal,
    #[derivative(Default(value = "Duration::milliseconds(0)"))]
	#[serde_as(as = "DurationMilliSeconds<i64>")]
	pub time_limit: Duration,
    #[derivative(Default(value = "Duration::milliseconds(0)"))]
	#[serde_as(as = "DurationMilliSeconds<i64>")]
	pub no_bingo_duration: Duration,
    pub overtime: bool,
    pub free_for_all: bool,
    pub rerolls: bool,
    pub mappack_id: Option<u32>,
    pub campaign_selection: Option<String>,
    #[derivative(Default(value = "Some(1)"))]
	pub map_tag: Option<i32>,
}

/* Request to open a connection by the client. */
#[serde_as]
#[derive(Serialize, Deserialize, Debug, Clone, Derivative)]
#[derivative(Default)]
pub struct HandshakeRequest {
    pub version: String,
    pub game: GamePlatform,
    pub username: Option<String>,
    pub token: Option<String>,
}

/* Supported game platforms in Bingo. */
#[derive(Serialize_repr, Deserialize_repr, Debug, PartialEq, Eq, Copy, Clone, Default)]
#[repr(u8)]
pub enum GamePlatform {
    #[default] Next,
    Turbo,
}

/* Available map selection modes. */
#[derive(Serialize_repr, Deserialize_repr, Debug, PartialEq, Eq, Copy, Clone, Default)]
#[repr(u8)]
pub enum MapMode {
    #[default] RandomTMX,
    Tags,
    Mappack,
    Campaign,
}

/* A Trackmania medal ranking. */
#[derive(Serialize_repr, Deserialize_repr, Debug, PartialEq, Eq, Copy, Clone, Default)]
#[repr(u8)]
pub enum Medal {
    #[default] Author,
    Gold,
    Silver,
    Bronze,
    None,
}
