use std::sync::OnceLock;

use crate::{integrations::webservices::NadeoWebserivcesClient, VERSION};
use once_cell::sync::Lazy;

pub mod openplanet;
pub mod tmexchange;
pub mod tmio;
pub mod webservices;

pub static USER_AGENT: Lazy<String> =
    Lazy::new(|| format!("TrackmaniaBingo/{} (Contact: @geekid)", VERSION));

pub static NADEOSERVICES_CLIENT: OnceLock<NadeoWebserivcesClient> = OnceLock::new();
