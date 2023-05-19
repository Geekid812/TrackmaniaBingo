use serde::Serialize;

use super::Response;

#[derive(Serialize, Debug)]
pub struct Ok;

#[typetag::serialize]
impl Response for Ok {}

#[derive(Serialize, Debug)]
pub struct Error {
    pub error: String,
}

impl From<anyhow::Error> for Error {
    fn from(value: anyhow::Error) -> Self {
        Self {
            error: format!("{}", value),
        }
    }
}

#[typetag::serialize]
impl Response for Error {}
