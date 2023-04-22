use serde::Serialize;

use crate::util::color::RgbColor;

pub type TeamIdentifier = usize;

#[derive(Clone, Serialize, Debug)]
pub struct GameTeam {
    pub id: TeamIdentifier,
    pub name: String,
    pub color: RgbColor,
}

impl GameTeam {
    pub fn new(id: usize, name: String, color: RgbColor) -> Self {
        Self { id, name, color }
    }
}

impl PartialEq for GameTeam {
    fn eq(&self, other: &Self) -> bool {
        self.id.eq(&other.id)
    }
}

impl Eq for GameTeam {}
