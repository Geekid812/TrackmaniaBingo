use serde::Serialize;
use std::hash::Hash;

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
    pub item_ident: Option<u32>,
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
            item_ident: None,
            writer: value.writer,
        }
    }
}

impl IngamePlayer {
    pub fn as_player_ref(&self) -> PlayerRef {
        PlayerRef {
            uid: self.profile.uid as u32,
            name: self.profile.name.clone(),
        }
    }
}

impl Hash for PlayerRef {
    fn hash<H: std::hash::Hasher>(&self, state: &mut H) {
        self.uid.hash(state);
    }
}
