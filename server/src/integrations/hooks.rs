use chrono::{DateTime, Utc};
use reqwest::{Client, IntoUrl, Url};
use serde::Serialize;
use tracing::error;

use crate::{
    core::models::team::NetworkGameTeam,
    datatypes::{MatchConfiguration, RoomConfiguration},
};

pub struct HooksClient {
    client: Client,
    endpoint: Url,
}

#[derive(Serialize, Clone, Debug)]
pub struct MatchEndEffect {
    pub uid: String,
    pub room_config: RoomConfiguration,
    pub match_config: MatchConfiguration,
    pub teams: Vec<NetworkGameTeam>,
    pub started: DateTime<Utc>,
    pub ended: DateTime<Utc>,
}

impl HooksClient {
    pub fn new(client: Client, endpoint: impl IntoUrl) -> Result<Self, reqwest::Error> {
        Ok(Self {
            client,
            endpoint: endpoint.into_url()?,
        })
    }

    pub async fn post_match_end(&self, effect: &MatchEndEffect) {
        let request = self.client.post(self.endpoint.clone()).json(effect);

        if let Err(err) = request.send().await {
            error!("post_match_end request: {}", err);
        }
    }
}
