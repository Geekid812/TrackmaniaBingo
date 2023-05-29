use serde::{Deserialize, Serialize};

use crate::core::util::color::RgbColor;

#[derive(Copy, Clone, PartialEq, Eq, Serialize, Debug, Hash, Deserialize)]
pub struct TeamIdentifier(usize);

#[derive(Clone, Serialize, Deserialize, Debug, Eq)]
pub struct BaseTeam {
    pub id: TeamIdentifier,
    pub name: String,
    pub color: RgbColor,
}

impl BaseTeam {
    pub fn new(id: usize, name: String, color: RgbColor) -> Self {
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
