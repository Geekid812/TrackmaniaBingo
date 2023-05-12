// Getting the country code of a player via the trackmania.io API

use std::{collections::HashMap, str::FromStr};

use once_cell::sync::Lazy;
use reqwest::{
    header::{HeaderMap, HeaderValue},
    Client, Url,
};
use rustc_version_runtime::version;
use tracing::debug;

use crate::{integrations::USER_AGENT, VERSION};

const ROUTE_PLAYER: &'static str = "/api/player/";

pub struct CountryIdentifier {
    client: Client,
}

impl CountryIdentifier {
    pub fn new() -> Self {
        debug!("user agent: {}", *USER_AGENT);
        let mut headers = HeaderMap::new();
        headers.insert("user-agent", HeaderValue::from_static(&USER_AGENT));
        Self {
            client: Client::builder()
                .default_headers(headers)
                .build()
                .expect("client should be built"),
        }
    }

    pub async fn get_country_code(
        &self,
        account_id: &str,
    ) -> Result<Option<String>, reqwest::Error> {
        let url = Url::from_str(&(super::BASE.to_owned() + ROUTE_PLAYER + account_id))
            .expect("country code url can be constructed");

        let response: serde_json::Value = self
            .client
            .get(url)
            .send()
            .await?
            .error_for_status()?
            .json()
            .await?;

        Ok(response
            .get("trophies")
            .and_then(|v| v.get("zone"))
            .and_then(Self::unwrap_as_country)
            .map(str::to_owned))
    }

    fn unwrap_as_country(val: &serde_json::Value) -> Option<&str> {
        let code = val.get("flag")?.as_str()?;
        if Self::is_country_code(code) {
            return Some(code);
        }
        Self::unwrap_as_country(val.get("parent")?)
    }

    fn is_country_code(s: &str) -> bool {
        s.len() == 3 && s.chars().all(|c| c.is_ascii_uppercase())
    }
}
