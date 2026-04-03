use serde::{Deserialize, Serialize};

// -- Handshake phase --

#[derive(Serialize)]
pub struct KeyExchangeRequest {
    pub key: String,
    pub display_name: String,
    pub account_id: String,
}

#[derive(Deserialize, Debug)]
pub struct TokenHint {
    pub token: String,
}

#[derive(Serialize)]
pub struct HandshakeRequest {
    pub version: String,
    pub game: u8,
    pub token: String,
}

#[derive(Deserialize, Debug)]
pub struct HandshakeResponse {
    pub success: bool,
    pub reason: Option<String>,
}

// -- Main loop requests --

#[derive(Serialize)]
pub struct BaseRequest<T: Serialize> {
    pub seq: u32,
    pub req: String,
    #[serde(flatten)]
    pub fields: T,
}

#[derive(Deserialize, Debug)]
pub struct BaseResponse {
    pub seq: Option<u32>,
    pub error: Option<String>,
    #[serde(flatten)]
    pub fields: serde_json::Value,
}

// -- Request payloads --

#[derive(Serialize)]
pub struct PingFields {}

#[derive(Serialize)]
pub struct CreateRoomFields {
    pub config: RoomConfig,
    pub match_config: MatchConfig,
    pub teams: Vec<Team>,
}

#[derive(Serialize)]
pub struct RoomConfig {
    pub name: String,
    pub public: bool,
    pub randomize: bool,
    pub size: u32,
    pub host_control: bool,
}

#[derive(Serialize)]
pub struct MatchConfig {
    pub game: u8,
    pub mode: u8,
    pub grid_size: u32,
    pub selection: u8,
    pub target_medal: u8,
    pub discovery: bool,
    pub secret: bool,
    pub time_limit: i64,
    pub no_bingo_duration: i64,
    pub overtime: bool,
    pub late_join: bool,
    pub rerolls: bool,
    pub competitve_patch: bool,
    pub mappack_id: Option<u32>,
    pub campaign_selection: Option<Vec<u32>>,
    pub map_tag: Option<i32>,
    pub items: FrenzyItemSettings,
    pub items_expire: u32,
    pub items_tick_multiplier: u32,
    pub rally_length: u32,
    pub jail_length: u32,
}

#[derive(Serialize)]
pub struct FrenzyItemSettings {
    pub row_shift: u32,
    pub column_shift: u32,
    pub rally: u32,
    pub jail: u32,
    pub rainbow: u32,
    pub golden_dice: u32,
}

#[derive(Serialize)]
pub struct Team {
    pub id: usize,
    pub name: String,
    pub color: [u8; 3],
}

#[derive(Serialize)]
pub struct JoinRoomFields {
    pub join_code: String,
}

#[derive(Serialize)]
pub struct SendChatMessageFields {
    pub message: String,
}

// -- Helpers --

impl Default for RoomConfig {
    fn default() -> Self {
        Self {
            name: "Bench Room".into(),
            public: false,
            randomize: false,
            size: 0,
            host_control: false,
        }
    }
}

impl Default for MatchConfig {
    fn default() -> Self {
        Self {
            game: 0,
            mode: 0,
            grid_size: 5,
            selection: 0,
            target_medal: 1,
            discovery: false,
            secret: false,
            time_limit: 0,
            no_bingo_duration: 0,
            overtime: true,
            late_join: true,
            rerolls: true,
            competitve_patch: false,
            mappack_id: None,
            campaign_selection: None,
            map_tag: Some(3),
            items: FrenzyItemSettings::default(),
            items_expire: 600,
            items_tick_multiplier: 1000,
            rally_length: 600,
            jail_length: 600,
        }
    }
}

impl Default for FrenzyItemSettings {
    fn default() -> Self {
        Self {
            row_shift: 3,
            column_shift: 3,
            rally: 3,
            jail: 3,
            rainbow: 3,
            golden_dice: 3,
        }
    }
}
