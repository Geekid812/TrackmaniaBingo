use std::{collections::HashMap, sync::Arc};

use futures::executor::block_on;
use once_cell::sync::Lazy;
use reqwest::StatusCode;
use sqlx::QueryBuilder;
use std::iter::once;
use tracing::error;
use warp::{http::Response, Filter};
use warp::{Rejection, Reply};

use crate::core::util::base64;
use crate::integrations::openplanet::ValidationError;
use crate::integrations::tmio::CountryIdentifier;
use crate::orm;
use crate::orm::models::player::NewPlayer;
use crate::{config::CONFIG, integrations::openplanet::Authenticator};

static AUTHENTICATOR: Lazy<Option<Arc<Authenticator>>> = Lazy::new(|| {
    if let Some(secret) = &CONFIG.secrets.openplanet_auth {
        Some(Arc::new(Authenticator::new(secret.to_owned())))
    } else {
        None
    }
});

static COUNTRY_IDENTIFIER: Lazy<Arc<CountryIdentifier>> =
    Lazy::new(|| Arc::new(CountryIdentifier::new()));

pub fn auth_routes() -> impl Filter<Extract = (impl Reply,), Error = Rejection> + Clone {
    let login = warp::get()
        .and(warp::path("login"))
        .and(warp::query::<HashMap<String, String>>())
        .map(|params: HashMap<String, String>| params.get("token").map(String::to_owned))
        .then(login);
    warp::path("auth").and(login)
}

async fn login(token: Option<String>) -> impl warp::Reply {
    match token {
        Some(token) => {
            let response = Response::builder();
            if AUTHENTICATOR.is_none() {
                unimplemented!()
            }
            match AUTHENTICATOR.as_ref().unwrap().validate(token).await {
                Ok(identity) => {
                    let token = base64::generate(32);
                    let country_result = COUNTRY_IDENTIFIER
                        .get_country_code(&identity.account_id)
                        .await;

                    if let Err(e) = &country_result {
                        error!("country code error: {}", e);
                    }
                    let country_code = country_result.unwrap_or(None);

                    let player = NewPlayer {
                        account_id: identity.account_id,
                        username: identity.display_name,
                        client_token: token.clone(),
                        country_code,
                    };
                    let result = orm::execute(move |mut conn| {
                        let mut builder = QueryBuilder::new("INSERT INTO players(account_id, username, client_token, country_code) ");
                        builder.push_values(once(player), |mut builder, p| {
                            p.bind_values(&mut builder)
                        });
                        builder.push(" ON CONFLICT(account_id) DO UPDATE SET client_token=excluded.client_token, username=excluded.username, country_code=excluded.country_code");
                        block_on(builder.build().execute(&mut *conn))
                    })
                    .await;
                    if let Err(exec_error) = result {
                        error!("execute error: {}", exec_error);
                    }
                    response.body(token)
                }
                Err(ValidationError::BackendError(e)) => {
                    response.status(StatusCode::UNAUTHORIZED).body(e)
                }
                Err(e) => {
                    error!("openplanet authentication error: {}", e);
                    response
                        .status(StatusCode::SERVICE_UNAVAILABLE)
                        .body(e.to_string())
                }
            }
        }
        None => Response::builder()
            .status(StatusCode::BAD_REQUEST)
            .body("query parameter 'token' is required".to_owned()),
    }
}
