// Interacting with the Openplanet Auth API

use reqwest::{multipart::Form, Client, Url};
use serde::Deserialize;
use std::str::FromStr;
use thiserror::Error;
use tracing::debug;

const AUTH_VALIDATE: &'static str = "/api/auth/validate";

pub struct Authenticator {
    client: Client,
    validate_route: Url,
    secret: String,
}

impl Authenticator {
    pub fn new(secret: String) -> Self {
        Self {
            client: Client::new(),
            validate_route: Url::from_str(&(super::BASE.to_owned() + AUTH_VALIDATE))
                .expect("Url should be valid"),
            secret,
        }
    }

    pub async fn validate(&self, token: String) -> Result<PlayerIdentity, ValidationError> {
        debug!("validating this token: {}", token);
        let form_data = Form::new()
            .text("token", token)
            .text("secret", self.secret.clone());

        let response: ResponseAuth = self
            .client
            .post(self.validate_route.clone())
            .multipart(form_data)
            .send()
            .await?
            .error_for_status()
            .map_err(ValidationError::RequestError)?
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

pub struct PlayerIdentity {
    pub account_id: String,
    pub display_name: String,
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
        #[allow(unused)]
        token_time: i64,
    },
}
