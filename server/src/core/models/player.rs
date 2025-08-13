use serde::Serialize;

use crate::{
    core::gamecommon::PlayerData,
    datatypes::{PlayerProfile, PlayerRef, Powerup},
    transport::messager::NetMessager,
};

#[derive(Serialize, Clone, Debug)]
pub struct IngamePlayer {
    #[serde(flatten)]
    pub profile: PlayerProfile,
    pub operator: bool,
    pub disconnected: bool,
    pub holding_powerup: Powerup,

    #[serde(skip)]
    pub writer: NetMessager,
}

impl From<PlayerData> for IngamePlayer {
    fn from(value: PlayerData) -> Self {
        Self {
            profile: value.profile,
            operator: value.operator,
            disconnected: value.disconnected,
            holding_powerup: Powerup::Empty,
            writer: value.writer,
        }
    }
}

impl IngamePlayer {
    pub fn as_player_ref(&self) -> PlayerRef {
        PlayerRef { uid: self.profile.uid as u32, name: self.profile.name.clone() }
    }
}
