use chrono::{DateTime, Duration, Utc};
use parking_lot::RwLock;
use reqwest::{Client, RequestBuilder, Response, StatusCode};
use serde::Deserialize;
use serde_json::{json, Value};
use serde_with::{serde_as, TimestampSeconds};
use thiserror::Error;
use tracing::info;

const NADEO_CORE_AUDIENCE: &'static str = "NadeoServices";
const NADEO_LIVE_AUDIENCE: &'static str = "NadeoLiveServices";

const ENDPOINT_AUTHENTICATE_TOKEN: &'static str =
    "https://prod.trackmania.core.nadeo.online/v2/authentication/token/basic";
const CORE_ENDPOINT_MAP_RECORDS_BY_ACCOUNT: &'static str =
    "https://prod.trackmania.core.nadeo.online/v2/mapRecords/by-account";
const LIVE_ENDPOINT_MAP_LEADERBOARDS: &'static str =
    "https://live-services.trackmania.nadeo.live/api/token/leaderboard/group/Personal_Best/map/";

pub struct NadeoWebserivcesClient {
    client: Client,
    username: String,
    password: String,
    core_credentials: RwLock<Option<WebservicesCredentialsInfo>>,
    live_credentials: RwLock<Option<WebservicesCredentialsInfo>>,
}

#[derive(Deserialize, Debug, Clone)]
#[serde(rename_all = "camelCase")]
pub struct WebserivcesToken {
    pub access_token: String,
    pub refresh_token: String,
}

pub struct WebservicesCredentialsInfo {
    pub token: WebserivcesToken,
    pub expiration: DateTime<Utc>,
}

#[derive(Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct WebserivcesMapRecord {
    pub account_id: String,
    pub filename: String,
    pub game_mode: String,
    pub map_record_id: String,
    pub medal: i32,
    pub record_score: WebservicesRecordScore,
    pub removed: bool,
    pub timestamp: DateTime<Utc>,
    pub url: String,
}

#[derive(Debug, Clone, Copy)]
pub enum NadeoAudience {
    Core,
    Live,
}

#[derive(Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct WebservicesRecordScore {
    pub respawn_count: i32,
    pub score: i32,
    pub time: i32,
}

#[serde_as]
#[derive(Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct WebservicesLeaderboardEntry {
    pub account_id: String,
    pub zone_id: String,
    pub zone_name: String,
    pub position: i32,
    pub score: i32,
    #[serde_as(as = "TimestampSeconds")]
    pub timestamp: DateTime<Utc>,
}

#[derive(Error, Debug)]
pub enum WebservicesError {
    #[error("invalid credentials for audience '{0:?}'")]
    NoCredientials(NadeoAudience),
    #[error(transparent)]
    Reqwest(reqwest::Error),
    #[error("unexpected response format")]
    InvalidResponse,
    #[error(transparent)]
    SerdeJson(serde_json::Error),
}

impl NadeoWebserivcesClient {
    pub fn new(client: Client, username: String, password: String) -> Self {
        Self {
            client,
            username,
            password,
            core_credentials: RwLock::new(None),
            live_credentials: RwLock::new(None),
        }
    }

    async fn prepare_request(&self, audience: NadeoAudience) {
        let credentials = match audience {
            NadeoAudience::Core => &self.core_credentials,
            NadeoAudience::Live => &self.live_credentials,
        };

        let has_valid_credentials = credentials
            .read()
            .as_ref()
            .is_some_and(|c| c.expiration > Utc::now());
        if !has_valid_credentials {
            self.refresh(audience).await;
        }
    }

    async fn send_request(
        &self,
        request: RequestBuilder,
        audience: NadeoAudience,
    ) -> Result<Response, WebservicesError> {
        self.prepare_request(audience).await;
        let Some(token) = self.get_request_token(audience) else {
            return Err(WebservicesError::NoCredientials(audience));
        };

        // TODO: handle expired tokens
        let authenticated = request.header(
            reqwest::header::AUTHORIZATION,
            format!("nadeo_v1 t={}", token),
        );
        authenticated
            .send()
            .await
            .map_err(WebservicesError::Reqwest)
    }

    fn get_request_token(&self, audience: NadeoAudience) -> Option<String> {
        let credentials = match audience {
            NadeoAudience::Core => self.core_credentials.read(),
            NadeoAudience::Live => self.live_credentials.read(),
        };
        let token = credentials
            .as_ref()
            .map(|credentials| &credentials.token.access_token);
        token.cloned()
    }

    async fn refresh_credentials(
        &self,
        audience: &str,
        credentials: &RwLock<Option<WebservicesCredentialsInfo>>,
    ) {
        match self
            .get_audience_token(audience, &self.username, &self.password)
            .await
        {
            Ok(token) => {
                let mut writer = credentials.write();
                *writer = Some(WebservicesCredentialsInfo {
                    token,
                    expiration: Utc::now() + Duration::minutes(30),
                });
            }
            Err(e) => tracing::error!(
                "failed to refresh credentials for audience '{}': {}",
                audience,
                e
            ),
        }
    }

    pub async fn refresh(&self, audience: NadeoAudience) {
        match audience {
            NadeoAudience::Core => {
                self.refresh_credentials(NADEO_CORE_AUDIENCE, &self.core_credentials)
                    .await
            }
            NadeoAudience::Live => {
                self.refresh_credentials(NADEO_LIVE_AUDIENCE, &self.live_credentials)
                    .await
            }
        }
    }

    async fn get_audience_token(
        &self,
        audience: &str,
        username: &str,
        password: &str,
    ) -> Result<WebserivcesToken, reqwest::Error> {
        let body = json!({
            "audience": audience
        });

        let request = self
            .client
            .post(ENDPOINT_AUTHENTICATE_TOKEN)
            .basic_auth(username, Some(password))
            .json(&body);
        let response: WebserivcesToken = request.send().await?.error_for_status()?.json().await?;

        Ok(response)
    }

    pub async fn core_get_map_records(
        &self,
        map_id: &str,
        account_ids: &Vec<String>,
    ) -> Result<Vec<WebserivcesMapRecord>, WebservicesError> {
        let request = self
            .client
            .get(CORE_ENDPOINT_MAP_RECORDS_BY_ACCOUNT)
            .query(&[("accountIdList", account_ids.join(","))])
            .query(&[("mapId", map_id)]);
        let response: Vec<WebserivcesMapRecord> = self
            .send_request(request, NadeoAudience::Core)
            .await?
            .json()
            .await
            .map_err(WebservicesError::Reqwest)?;

        Ok(response)
    }

    pub async fn live_get_map_leaderboard(
        &self,
        map_uid: &str,
    ) -> Result<Vec<WebservicesLeaderboardEntry>, WebservicesError> {
        let request = self
            .client
            .get(format!("{}{}/top", LIVE_ENDPOINT_MAP_LEADERBOARDS, map_uid));
        let response: Value = self
            .send_request(request, NadeoAudience::Live)
            .await?
            .json()
            .await
            .map_err(WebservicesError::Reqwest)?;

        let top = response
            .get("tops")
            .and_then(|r| r.get(0))
            .and_then(|r| r.get("top"))
            .and_then(|r| r.as_array());

        match top {
            Some(value) => Ok(value
                .iter()
                .map(|v| serde_json::from_value(v.clone()))
                .filter(|e| e.is_ok())
                .map(Result::unwrap)
                .collect()),
            None => Err(WebservicesError::InvalidResponse),
        }
    }
}
