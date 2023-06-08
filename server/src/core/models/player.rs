use serde::{Deserialize, Serialize};

use crate::{core::room::PlayerData, orm::composed::profile::PlayerProfile};

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct Player {
    #[serde(flatten)]
    pub profile: PlayerProfile,
    pub operator: bool,
    pub disconnected: bool,
}

impl From<&PlayerData> for Player {
    fn from(value: &PlayerData) -> Self {
        Self {
            profile: value.profile.clone(),
            operator: value.operator,
            disconnected: value.disconnected,
        }
    }
}
