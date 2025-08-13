use palette::serde::as_array;
use serde::{Deserialize, Serialize};

use crate::core::events::game::GameEvent;
use crate::core::{teams::Team, util::Color};
use crate::transport::Channel;

use super::player::IngamePlayer;
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

#[derive(Clone, Debug)]
pub struct GameTeam {
    pub base: BaseTeam,
    pub members: Vec<IngamePlayer>,
    pub channel: Channel<GameEvent>,
    pub winner: bool,
}

#[derive(Serialize, Clone, Debug)]
pub struct NetworkGameTeam {
    pub base: BaseTeam,
    pub members: Vec<IngamePlayer>,
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
        let mut channel = Channel::new();
        value
            .members
            .iter()
            .for_each(|player| channel.subscribe(player.profile.uid, player.writer.clone()));
        Self {
            base: value.base,
            members: value.members.into_iter().map(IngamePlayer::from).collect(),
            channel,
            winner: false,
        }
    }
}

impl From<&GameTeam> for NetworkGameTeam {
    fn from(value: &GameTeam) -> Self {
        Self {
            base: value.base.clone(),
            members: value.members.clone(),
        }
    }
}

impl Team for GameTeam {
    fn base(&self) -> &BaseTeam {
        &self.base
    }
}
