use palette::serde::as_array;
use serde::{Deserialize, Serialize};

use crate::core::util::Color;

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
