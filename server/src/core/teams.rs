use palette::{FromColor, Hsv, Srgb};
use rand::Rng;
use tracing::warn;

use super::{
    models::team::{BaseTeam, TeamIdentifier},
    util::Color,
};

pub trait Team {
    fn base(&self) -> &BaseTeam;
}

pub struct TeamsManager<T: Team> {
    teams: Vec<T>,
    teams_id: usize,
}

impl<T: Team + From<BaseTeam>> TeamsManager<T> {
    pub fn create_team_from_preset(&mut self, teams: &Vec<(String, Color)>) -> Option<&T> {
        let team_count = self.teams.len();
        if team_count >= teams.len() {
            warn!("attempted to create more than {} teams", teams.len());
            return None;
        }

        let mut rng = rand::thread_rng();
        let mut idx = rng.gen_range(0..teams.len());
        let mut retries = 100;
        while self.exists_with_name(&teams[idx].0) && retries > 0 {
            idx = rng.gen_range(0..teams.len());
            retries -= 1;
        }

        let color = teams[idx].1;
        Some(self.inner_create_team(teams[idx].0.clone(), color))
    }

    pub fn create_random_team(&mut self, name: String) -> &T {
        let mut rng = rand::thread_rng();
        let (h, s, v) = (
            rng.gen_range(0..=255),
            rng.gen_range(128..=255),
            rng.gen_range(128..=255),
        );
        let color: Hsv = Hsv::new_srgb(h, s, v).into_format::<f32>();
        let rgb = Srgb::from_color(color).into_format::<u8>();
        self.inner_create_team(name, rgb)
    }

    pub fn create_team(&mut self, name: String, color: Color) -> &T {
        self.inner_create_team(name, color)
    }

    fn inner_create_team(&mut self, name: String, color: Color) -> &T {
        let team = BaseTeam::new(self.teams_id, name, color);
        self.teams_id += 1;
        self.teams.push(T::from(team));
        self.teams.last().unwrap()
    }
}

impl<T: Team> TeamsManager<T> {
    pub fn new() -> Self {
        Self {
            teams: Vec::new(),
            teams_id: 0,
        }
    }

    pub fn from_teams(teams: Vec<T>, teams_id: usize) -> Self {
        Self { teams, teams_id }
    }

    pub fn get_teams(&self) -> &Vec<T> {
        &self.teams
    }

    pub fn teams_id(&self) -> usize {
        self.teams_id
    }

    pub fn get(&self, id: TeamIdentifier) -> Option<&T> {
        self.teams.iter().filter(|p| p.base().id == id).next()
    }

    pub fn get_mut(&mut self, id: TeamIdentifier) -> Option<&mut T> {
        self.teams.iter_mut().filter(|p| p.base().id == id).next()
    }

    pub fn get_index(&self, index: usize) -> Option<&T> {
        self.teams.get(index)
    }

    pub fn remove_team(&mut self, id: TeamIdentifier) -> Option<T> {
        if self.teams.len() <= 1 {
            warn!("attempted to delete when 1 or less team is left");
            return None;
        }

        let searched = self
            .teams
            .iter()
            .enumerate()
            .find(|(_, t)| t.base().id == id)
            .map(|(i, t)| (i, t.to_owned()));
        if let Some((i, _)) = searched {
            return Some(self.teams.remove(i));
        }
        None
    }

    pub fn exists(&self, id: TeamIdentifier) -> bool {
        self.teams.iter().find(|t| t.base().id == id).is_some()
    }

    pub fn exists_with_name(&self, name: &str) -> bool {
        self.teams.iter().any(|t| t.base().name == name)
    }

    pub fn count(&self) -> usize {
        self.teams.len()
    }
}
