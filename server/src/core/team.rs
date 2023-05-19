use std::sync::atomic::{AtomicUsize, Ordering};

use serde::{Deserialize, Serialize};

use super::util::color::RgbColor;

static TEAMID: AtomicUsize = AtomicUsize::new(0);

#[derive(Copy, Clone, PartialEq, Eq, Serialize, Debug, Hash, Deserialize)]
pub struct TeamIdentifier(usize);

#[derive(Clone, Serialize, Debug)]
pub struct BaseTeam {
    pub id: TeamIdentifier,
    pub name: String,
    pub color: RgbColor,
}

impl BaseTeam {
    pub fn new(name: String, color: RgbColor) -> Self {
        Self {
            id: TeamIdentifier(TEAMID.fetch_add(1, Ordering::Relaxed)),
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

impl Eq for BaseTeam {}
