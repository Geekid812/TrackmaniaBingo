use serde::{Serialize};

use crate::{core::gamecommon::PlayerData, datatypes::PlayerProfile, transport::messager::NetMessager};


#[derive(Serialize, Clone, Debug)]
pub struct Player {
    #[serde(flatten)]
    pub profile: PlayerProfile,
    pub operator: bool,
    pub disconnected: bool,
    #[serde(skip)]
    pub writer: NetMessager
}

impl From<&PlayerData> for Player {
    fn from(value: &PlayerData) -> Self {
        Self {
            profile: value.profile.clone(),
            operator: value.operator,
            disconnected: value.disconnected,
            writer: value.writer.clone()
        }
    }
}
