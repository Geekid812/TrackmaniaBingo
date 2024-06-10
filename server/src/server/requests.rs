use serde::{Deserialize, Serialize};

use super::handlers::{Request, Response};

#[derive(Deserialize, Debug)]
pub struct BaseRequest {
    #[serde(rename = "seq")]
    sequence: i32,
    #[serde(flatten)]
    pub request: Box<dyn Request>,
}

impl BaseRequest {
    pub fn build_reply(&self, response: Box<dyn Response>) -> BaseResponse {
        BaseResponse {
            sequence: self.sequence,
            response: response,
        }
    }
}

#[derive(Serialize, Debug)]
pub struct BaseResponse {
    #[serde(rename = "seq")]
    sequence: i32,
    #[serde(flatten)]
    pub response: Box<dyn Response>,
}

impl BaseResponse {
    /// Build a `BaseResponse` without a matching sequence identifier.
    pub fn bare(response: Box<dyn Response>) -> Self {
        Self {
            sequence: -1,
            response,
        }
    }
}
