use std::sync::Arc;

use anyhow::anyhow;
use once_cell::sync::Lazy;
use serde::Deserialize;
use tracing::error;

use crate::core::util::base64;
use crate::datatypes::KeyExchangeRequest;
use crate::integrations::openplanet::Authenticator;
use crate::integrations::openplanet::ValidationError;
use crate::integrations::tmio::CountryIdentifier;
use crate::store::player::NewPlayer;
use crate::{config, store};

use super::token::set_player_token;

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

#[derive(Deserialize)]
enum AuthenticationMethod {
    Openplanet,
    None,
}

/// Handling logic for authenticating new players.
pub async fn login(request: KeyExchangeRequest) -> Result<String, anyhow::Error> {
    let player: NewPlayer = match request.key {
        key if key.is_empty() => {
            if !config::is_development() {
                return Err(anyhow!("must provide an Openplanet authentication key when production mode is activated")
                    );
            }
            let country_result = COUNTRY_IDENTIFIER
                .get_country_code(&request.account_id)
                .await;

            if let Err(e) = &country_result {
                error!("error fetching country code: {}", e);
            }
            let country_code = country_result.unwrap_or(None);

            NewPlayer {
                account_id: request.account_id,
                username: request.display_name,
                country_code,
            }
        }
        key => {
            if AUTHENTICATOR.is_none() {
                return Err(anyhow!(
                    "Openplanet auth key exchange is not configured on this server"
                ));
            }

            match AUTHENTICATOR.as_ref().unwrap().validate(key).await {
                Ok(identity) => {
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
                        country_code,
                    }
                }
                Err(ValidationError::BackendError(e)) => {
                    return Err(anyhow!(e));
                }
                Err(e) => {
                    error!("openplanet authentication error: {}", e);
                    return Err(e.into());
                }
            }
        }
    };

    let client_token = base64::generate(32);

    match store::player::create_or_update_player(player).await {
        Ok(uid) => {
            set_player_token(uid, client_token.clone());
            Ok(client_token)
        }
        Err(e) => Err(anyhow!("database error: {}", e)),
    }
}
