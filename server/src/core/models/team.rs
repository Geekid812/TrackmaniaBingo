use palette::serde::as_array;
use serde::{Deserialize, Serialize};

use crate::core::events::game::GameEvent;
use crate::core::{teams::Team, util::Color};
use crate::transport::Channel;

use super::player::Player;
use super::room::RoomTeam;

#[derive(Copy, Clone, PartialEq, Eq, Serialize, Debug, Hash, Deserialize)]
pub struct TeamIdentifier(usize);

#[derive(Clone, Serialize, Deserialize, Debug, Eq)]
pub struct BaseTeam {
    pub id: TeamIdentifier,
    pub name: String,
    #[serde(with = "as_array")]
    pub color: Color,
}

impl BaseTeam {
    pub fn new(id: usize, name: String, color: Color) -> Self {
        Self {
            id: TeamIdentifier(id),
            name,
            color,
        }
    }
}

impl PartialEq for BaseTeam {
    fn eq(&self, other: &Self) -> bool {
        self.id.eq(&other.id)
    }
}

impl Team for BaseTeam {
    fn base(&self) -> &BaseTeam {
        &self
    }
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct GameTeam {
    pub base: BaseTeam,
    pub members: Vec<Player>,
    #[serde(skip)]
    pub channel: Channel<GameEvent>,
    #[serde(skip)]
    pub winner: bool,
}

impl From<BaseTeam> for GameTeam {
    fn from(value: BaseTeam) -> Self {
        Self {
            base: value,
            members: Vec::new(),
            channel: Channel::new(),
            winner: false,
        }
    }
}

impl From<RoomTeam> for GameTeam {
    fn from(value: RoomTeam) -> Self {
        Self {
            base: value.base,
            members: value.members,
            channel: Channel::new(),
            winner: false,
        }
    }
}

impl Team for GameTeam {
    fn base(&self) -> &BaseTeam {
        &self.base
    }
}
