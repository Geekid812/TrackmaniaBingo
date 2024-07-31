use std::sync::Arc;

use once_cell::sync::Lazy;
use reqwest::StatusCode;
use serde::Deserialize;
use tracing::error;
use warp::{http::Response, Filter};
use warp::{post, Rejection, Reply};

use crate::integrations::openplanet::Authenticator;
use crate::integrations::openplanet::ValidationError;
use crate::integrations::tmio::CountryIdentifier;
use crate::store::player::NewPlayer;
use crate::util::base64;
use crate::{config, store};

static AUTHENTICATOR: Lazy<Option<Arc<Authenticator>>> = Lazy::new(|| {
    if let Some(secret) = config::get_string("keys.openplanet") {
        // check that it was replaced from the default value
        if secret != "KEY" {
            return Some(Arc::new(Authenticator::new(secret.to_owned())));
        }
    }
    None
});

static COUNTRY_IDENTIFIER: Lazy<Arc<CountryIdentifier>> =
    Lazy::new(|| Arc::new(CountryIdentifier::new()));

pub fn get_routes() -> impl Filter<Extract = (impl Reply,), Error = Rejection> + Clone {
    let login = post()
        .and(warp::path("login"))
        .and(warp::body::json())
        .then(login);
    warp::path("auth").and(login)
}

#[derive(Deserialize)]
struct AuthenticationRequestBody {
    authentication: AuthenticationMethod,
    account_id: String,
    display_name: String,
    token: Option<String>,
}

#[derive(Deserialize)]
enum AuthenticationMethod {
    Openplanet,
    None,
}

/// Handling logic for authenticating new players.
async fn login(body: AuthenticationRequestBody) -> impl warp::Reply {
    let player: NewPlayer = match body.authentication {
        AuthenticationMethod::Openplanet => {
            if AUTHENTICATOR.is_none() {
                return Response::builder().status(StatusCode::BAD_REQUEST).body(
                    "AuthenticationMethod::Openplanet is not configured on this server".to_string(),
                );
            }

            let Some(token) = body.token else {
                return Response::builder()
                    .status(StatusCode::BAD_REQUEST)
                    .body("parameter 'token' was not provided".to_string());
            };

            match AUTHENTICATOR.as_ref().unwrap().validate(token).await {
                Ok(identity) => {
                    let client_token = base64::generate(32);
                    let country_result = COUNTRY_IDENTIFIER
                        .get_country_code(&identity.account_id)
                        .await;

                    if let Err(e) = &country_result {
                        error!("error fetching country code: {}", e);
                    }
                    let country_code = country_result.unwrap_or(None);

                    NewPlayer {
                        account_id: identity.account_id,
                        username: identity.display_name,
                        client_token,
                        country_code,
                    }
                }
                Err(ValidationError::BackendError(e)) => {
                    return Response::builder().status(StatusCode::UNAUTHORIZED).body(e);
                }
                Err(e) => {
                    error!("openplanet authentication error: {}", e);
                    return Response::builder()
                        .status(StatusCode::SERVICE_UNAVAILABLE)
                        .body(e.to_string());
                }
            }
        }
        AuthenticationMethod::None => {
            if !config::is_development() {
                return Response::builder().status(StatusCode::FORBIDDEN).body(
                    "AuthenticationMethod::None is not available when not in a development environment"
                        .to_string(),
                    );
            }

            let client_token = base64::generate(32);
            let country_result = COUNTRY_IDENTIFIER.get_country_code(&body.account_id).await;

            if let Err(e) = &country_result {
                error!("error fetching country code: {}", e);
            }
            let country_code = country_result.unwrap_or(None);

            NewPlayer {
                account_id: body.account_id,
                username: body.display_name,
                client_token,
                country_code,
            }
        }
    };

    let token = player.client_token.clone();
    let response = Response::builder();
    if store::player::create_or_update_player(player).await.is_ok() {
        response.body(token)
    } else {
        response
            .status(StatusCode::BAD_REQUEST)
            .body("database error".to_string())
    }
}
