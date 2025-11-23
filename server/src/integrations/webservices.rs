use chrono::{DateTime, Utc};
use parking_lot::RwLock;
use reqwest::{Client, RequestBuilder, Response};
use serde::Deserialize;
use serde_json::json;
use thiserror::Error;

const NADEO_CORE_AUDIENCE: &'static str = "NadeoServices";
const NADEO_LIVE_AUDIENCE: &'static str = "NadeoLiveServices";

const ENDPOINT_AUTHENTICATE_TOKEN: &'static str =
    "https://prod.trackmania.core.nadeo.online/v2/authentication/token/basic";
const CORE_ENDPOINT_MAP_RECORDS_BY_ACCOUNT: &'static str =
    "https://prod.trackmania.core.nadeo.online/v2/mapRecords/by-account";

pub struct NadeoWebserivcesClient {
    client: Client,
    username: String,
    password: String,
    core_credentials: RwLock<Option<WebserivcesToken>>,
    live_credentials: RwLock<Option<WebserivcesToken>>,
}

#[derive(Deserialize, Debug, Clone)]
#[serde(rename_all = "camelCase")]
pub struct WebserivcesToken {
    pub access_token: String,
    pub refresh_token: String,
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

#[derive(Error, Debug)]
pub enum WebservicesError {
    #[error("invalid credentials for audience '{0:?}'")]
    NoCredientials(NadeoAudience),
    #[error(transparent)]
    Reqwest(reqwest::Error),
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

        let has_valid_credentials = credentials.read().is_some();
        if !has_valid_credentials {
            self.refresh(audience).await;
        }
    }

    async fn send_core_request(
        &self,
        request: RequestBuilder,
    ) -> Result<Response, WebservicesError> {
        self.prepare_request(NadeoAudience::Core).await;

        let credentials = self.core_credentials.read();
        let core_token = credentials
            .as_ref()
            .map(|credentials| &credentials.access_token);
        let Some(token) = core_token else {
            return Err(WebservicesError::NoCredientials(NadeoAudience::Core));
        };

        // TODO: handle expired tokens
        request
            .header(
                reqwest::header::AUTHORIZATION,
                format!("nadeo_v1 t={}", token),
            )
            .send()
            .await
            .map_err(WebservicesError::Reqwest)
    }

    async fn refresh_credentials(
        &self,
        audience: &str,
        credentials: &RwLock<Option<WebserivcesToken>>,
    ) {
        match self
            .get_audience_token(audience, &self.username, &self.password)
            .await
        {
            Ok(token) => {
                let mut writer = credentials.write();
                *writer = Some(token);
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
        account_ids: Vec<&str>,
    ) -> Result<Vec<WebserivcesMapRecord>, WebservicesError> {
        let request = self
            .client
            .get(CORE_ENDPOINT_MAP_RECORDS_BY_ACCOUNT)
            .query(&[("accountIdList", account_ids.join(","))])
            .query(&[("mapId", map_id)]);
        let response: Vec<WebserivcesMapRecord> = self
            .send_core_request(request)
            .await?
            .json()
            .await
            .map_err(WebservicesError::Reqwest)?;

        Ok(response)
    }
}
