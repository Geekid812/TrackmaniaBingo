// Interacting with the Openplanet Auth API
use reqwest::{multipart::Form, Client, Url};
use serde::Deserialize;
use std::hash::Hash;
use thiserror::Error;

use crate::config::AUTHENTICATION_API_SECRET;

pub struct Authenticator {
    client: Client,
    validate_route: Url,
}

impl Authenticator {
    pub fn new(client: Client, validate_route: Url) -> Self {
        Self {
            client,
            validate_route,
        }
    }

    pub async fn validate(&self, token: String) -> Result<PlayerIdentity, ValidationError> {
        let form_data = Form::new()
            .text("token", token)
            .text("secret", AUTHENTICATION_API_SECRET.unwrap());

        let response: ResponseAuth = self
            .client
            .post(self.validate_route.clone())
            .multipart(form_data)
            .send()
            .await?
            .json()
            .await?;

        match response {
            ResponseAuth::Identified {
                account_id,
                display_name,
                ..
            } => Ok(PlayerIdentity {
                account_id,
                display_name,
            }),
            ResponseAuth::Error { error } => Err(ValidationError::BackendError(error)),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PlayerIdentity {
    pub account_id: String,
    pub display_name: String,
}

impl Hash for PlayerIdentity {
    fn hash<H: std::hash::Hasher>(&self, state: &mut H) {
        self.account_id.hash(state);
    }
}

#[derive(Error, Debug)]
pub enum ValidationError {
    #[error(transparent)]
    RequestError(#[from] reqwest::Error),

    #[error("{0}")]
    BackendError(String),
}

#[derive(Deserialize)]
#[serde(untagged)]
enum ResponseAuth {
    Error {
        error: String,
    },
    Identified {
        account_id: String,
        display_name: String,
        #[allow(unused)] // TODO: how should this be used?
        token_time: i64,
    },
}
