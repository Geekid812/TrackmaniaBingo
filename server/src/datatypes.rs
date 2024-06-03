// This file is automatically @generated by the `typegen` tool.
// Do not manually edit it! See `common/types.xml` for details.
#![allow(unused_imports)]
use chrono::{DateTime, Duration, Utc};
use derivative::Derivative;
use serde::{Deserialize, Serialize};
use serde_repr::{Deserialize_repr, Serialize_repr};
use serde_with::{serde_as, DurationMilliSeconds, TimestampSeconds};

use crate::core::util::Color;

/* A simple reference to a registered player. */
#[serde_as]
#[derive(Serialize, Deserialize, Debug, Clone, Derivative, PartialEq, Eq)]
#[derivative(Default)]
#[serde(default)]
pub struct PlayerRef {
    pub uid: u32,
    pub name: String,
}

/* Room parameters set by the host. */
#[serde_as]
#[derive(Serialize, Deserialize, Debug, Clone, Derivative, PartialEq, Eq)]
#[derivative(Default)]
#[serde(default)]
pub struct RoomConfiguration {
    pub name: String,
    pub public: bool,
    pub randomize: bool,
    pub size: u32,
}

/* Match parameters set by the host. */
#[serde_as]
#[derive(Serialize, Deserialize, Debug, Clone, Derivative, PartialEq, Eq)]
#[derivative(Default)]
#[serde(default)]
pub struct MatchConfiguration {
    #[derivative(Default(value = "GamePlatform::Next"))]
	pub game: GamePlatform,
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
    pub competitve_patch: bool,
    pub mappack_id: Option<u32>,
    pub campaign_selection: Option<Vec<u32>>,
    #[derivative(Default(value = "Some(1)"))]
	pub map_tag: Option<i32>,
}

/* Request to open a connection by the client. */
#[serde_as]
#[derive(Serialize, Deserialize, Debug, Clone, Derivative, PartialEq, Eq)]
#[derivative(Default)]
#[serde(default)]
pub struct HandshakeRequest {
    pub version: String,
    pub game: GamePlatform,
    pub token: String,
}

/* A map identifier for an official campaign. */
#[serde_as]
#[derive(Serialize, Deserialize, Debug, Clone, Derivative, PartialEq, Eq)]
#[derivative(Default)]
#[serde(default)]
pub struct CampaignMap {
    #[derivative(Default(value = "-1"))]
	pub campaign_id: i32,
    #[derivative(Default(value = "-1"))]
	pub map: i32,
}

/* A message sent by a player in a text chat. */
#[serde_as]
#[derive(Serialize, Deserialize, Debug, Clone, Derivative, PartialEq, Eq)]
#[derivative(Default)]
#[serde(default)]
pub struct ChatMessage {
    pub uid: u32,
    pub name: String,
    pub title: Option<String>,
    #[serde_as(as = "TimestampSeconds")]
	pub timestamp: DateTime<Utc>,
    pub content: String,
    pub team_message: bool,
}

/* One of the available options in a poll. */
#[serde_as]
#[derive(Serialize, Deserialize, Debug, Clone, Derivative, PartialEq, Eq)]
#[derivative(Default)]
#[serde(default)]
pub struct PollChoice {
    pub text: String,
    pub color: Color,
}

/* A set of choices to which players can answer. */
#[serde_as]
#[derive(Serialize, Deserialize, Debug, Clone, Derivative, PartialEq, Eq)]
#[derivative(Default)]
#[serde(default)]
pub struct Poll {
    pub id: u32,
    pub title: String,
    pub color: Color,
    #[derivative(Default(value = "Duration::milliseconds(0)"))]
	#[serde_as(as = "DurationMilliSeconds<i64>")]
	pub duration: Duration,
    pub choices: Vec<PollChoice>,
}

/* Supported game platforms in Bingo. */
#[derive(Serialize_repr, Deserialize_repr, Debug, PartialEq, Eq, Copy, Clone, Default)]
#[repr(u8)]
pub enum GamePlatform {
    #[default]
    Next,
    Turbo,
}

/* Available map selection modes. */
#[derive(Serialize_repr, Deserialize_repr, Debug, PartialEq, Eq, Copy, Clone, Default)]
#[repr(u8)]
pub enum MapMode {
    #[default]
    RandomTMX,
    Tags,
    Mappack,
    Campaign,
}

/* A Trackmania medal ranking. */
#[derive(Serialize_repr, Deserialize_repr, Debug, PartialEq, Eq, Copy, Clone, Default)]
#[repr(u8)]
pub enum Medal {
    #[default]
    Author,
    Gold,
    Silver,
    Bronze,
    None,
}

/* When a connection to the server fails, give the client a hint of what it should do. */
#[derive(Serialize_repr, Deserialize_repr, Debug, PartialEq, Eq, Copy, Clone, Default)]
#[repr(u8)]
pub enum HandshakeFailureIntentCode {
    #[default]
    ShowError,
    RequireUpdate,
    Reauthenticate,
}
