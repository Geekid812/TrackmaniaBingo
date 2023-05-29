use crate::transport::Channel;
use chrono::{DateTime, Utc};
use serde::Serialize;
use serde_repr::Serialize_repr;

use super::{
    events::game::GameEvent,
    map::GameMap,
    models::{
        self,
        livegame::Medal,
        team::{BaseTeam, TeamIdentifier},
    },
    room::{NetworkPlayer, PlayerData},
    util::base64,
};

pub type MatchConfiguration = models::livegame::MatchConfiguration;

pub struct LiveMatch {
    uid: String,
    config: MatchConfiguration,
    teams: Vec<GameTeam>,
    cells: Vec<GameCell>,
    started: DateTime<Utc>,
    channel: Channel<GameEvent>,
}

impl LiveMatch {
    pub fn new(config: MatchConfiguration, maps: Vec<GameMap>, teams: Vec<GameTeam>) -> Self {
        Self {
            uid: base64::generate(16),
            config,
            teams,
            cells: maps
                .into_iter()
                .map(|map| GameCell { map, claim: None })
                .collect(),
            started: Utc::now(),
            channel: Channel::new(),
        }
    }

    pub fn check_for_bingos(&self, grid_size: usize) -> Vec<BingoLine> {
        let mut bingos = Vec::new();
        // Horizontal
        for i in 0..grid_size {
            let line = self.cells[i * grid_size..(i + 1) * grid_size]
                .iter()
                .take(grid_size);

            let unique_team = iter_check_unique_team(line);

            if let Some(team) = unique_team {
                bingos.push(BingoLine {
                    direction: Direction::Horizontal,
                    index: i as u32,
                    team,
                });
            }
        }

        // Vertical
        for i in 0..grid_size {
            let mut iter = self.cells.iter();

            // Advance by i items to align column
            for _ in 0..i {
                iter.next();
            }

            let col = iter.step_by(grid_size);
            let unique_team = iter_check_unique_team(col);

            if let Some(team) = unique_team {
                bingos.push(BingoLine {
                    direction: Direction::Vertical,
                    index: i as u32,
                    team,
                });
            }
        }

        // Diagonal
        let mut diag0 = Vec::with_capacity(grid_size);
        let mut diag1 = Vec::with_capacity(grid_size);

        for i in 0..grid_size {
            diag0.push(self.cells.get(i * grid_size + i).unwrap());
            diag1.push(self.cells.get((grid_size - 1) * (i + 1)).unwrap());
        }

        let unique_team0 = iter_check_unique_team(diag0.into_iter());
        let unique_team1 = iter_check_unique_team(diag1.into_iter());

        if let Some(team) = unique_team0 {
            bingos.push(BingoLine {
                direction: Direction::Diagonal,
                index: 0,
                team,
            });
        }

        if let Some(team) = unique_team1 {
            bingos.push(BingoLine {
                direction: Direction::Diagonal,
                index: 1,
                team,
            });
        }

        bingos
    }
}

pub struct GameTeam {
    pub info: BaseTeam,
    pub members: Vec<PlayerData>,
}

pub struct GameCell {
    pub map: GameMap,
    pub claim: Option<MapClaim>,
}

#[derive(Serialize, Clone)]
pub struct MapClaim {
    pub player: NetworkPlayer,
    pub time: u64,
    pub medal: Medal,
}

#[derive(Serialize, Clone)]
pub struct BingoLine {
    pub direction: Direction,
    pub index: u32,
    pub team: TeamIdentifier,
}

#[derive(Serialize_repr, Clone, Copy)]
#[repr(u32)]
pub enum Direction {
    None = 0,
    Horizontal = 1,
    Vertical = 2,
    Diagonal = 3,
}

fn iter_check_unique_team<'a>(
    mut iter: impl Iterator<Item = &'a GameCell>,
) -> Option<TeamIdentifier> {
    let first = iter
        .next()
        .expect("invalid grid_size")
        .claim
        .as_ref()
        .map(|c| c.player.team);
    iter.fold(first, |acc, x| {
        acc.and_then(|y| {
            if x.claim.as_ref().map(|c| c.player.team) == Some(y) {
                Some(y)
            } else {
                None
            }
        })
    })
}
