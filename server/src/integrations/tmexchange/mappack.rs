// Load mappack maps from TrackmaniaExchange

use std::str::FromStr;

use anyhow::anyhow;
use reqwest::{
    header::{HeaderMap, HeaderValue},
    Client, Url,
};
use tracing::error;

use crate::{
    core::models::map::GameMap, integrations::USER_AGENT, orm::mapcache::record::MapRecord,
};

const ROUTE_MAPPACK: &'static str = "/api/mappack/get_mappack_tracks/";

pub struct MappackLoader {
    client: Client,
}

impl MappackLoader {
    pub fn new() -> Self {
        let mut headers = HeaderMap::new();
        headers.insert("user-agent", HeaderValue::from_static(&USER_AGENT));
        Self {
            client: Client::builder()
                .default_headers(headers)
                .build()
                .expect("client should be built"),
        }
    }

    pub async fn get_mappack_tracks(
        &self,
        mappack_id: &str,
    ) -> Result<Vec<GameMap>, anyhow::Error> {
        let url = Url::from_str(&(super::BASE.to_owned() + ROUTE_MAPPACK + mappack_id))
            .expect("mappack url can be constructed");

        let response: serde_json::Value = self
            .client
            .get(url)
            .send()
            .await?
            .error_for_status()?
            .json()
            .await?;

        let maps: Vec<GameMap> = response
            .get("results")
            .ok_or(anyhow!(
                "compatibility error when parsing JSON: {:?}",
                response
            ))?
            .as_array()
            .ok_or(anyhow!("invalid JSON received: {:?}", response))?
            .to_owned()
            .into_iter()
            .map(serde_json::from_value::<MapRecord>)
            .filter(|m| {
                if let Err(e) = m {
                    error!("invalid map loaded: {}", e);
                }
                m.is_ok()
            })
            .map(Result::unwrap)
            .map(GameMap::TMX)
            .collect();

        Ok(maps)
    }
}
