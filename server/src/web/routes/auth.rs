use std::{collections::HashMap, sync::Arc};

use diesel::{AsChangeset, Insertable, RunQueryDsl};
use once_cell::sync::Lazy;
use reqwest::StatusCode;
use tracing::error;
use warp::{http::Response, Filter};
use warp::{Rejection, Reply};

use crate::core::util::base64;
use crate::integrations::openplanet::ValidationError;
use crate::orm;
use crate::orm::schema::players;
use crate::{config::CONFIG, integrations::openplanet::Authenticator};

static AUTHENTICATOR: Lazy<Option<Arc<Authenticator>>> = Lazy::new(|| {
    if let Some(secret) = &CONFIG.secrets.openplanet_auth {
        Some(Arc::new(Authenticator::new(secret.to_owned())))
    } else {
        None
    }
});

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
                    let player = NewPlayer {
                        account_id: identity.account_id,
                        username: identity.display_name,
                        client_token: token.clone(),
                        country_code: None, // TODO: integrate TM.io to get country code
                    };
                    let result = orm::execute(move |conn| {
                        diesel::insert_into(players::table)
                            .values(&player)
                            .on_conflict(players::columns::account_id)
                            .do_update()
                            .set(&player)
                            .execute(conn)
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

#[derive(Insertable, AsChangeset)]
#[diesel(table_name = players)]
pub struct NewPlayer {
    pub account_id: String,
    pub username: String,
    pub client_token: String,
    pub country_code: Option<String>,
}
