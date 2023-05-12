use once_cell::sync::Lazy;
use rustc_version_runtime::version;

use crate::VERSION;

pub mod openplanet;
pub mod tmexchange;
pub mod tmio;

static USER_AGENT: Lazy<String> =
    Lazy::new(|| format!("TrackmaniaBingo/{} rustc/{}", VERSION, version()));
