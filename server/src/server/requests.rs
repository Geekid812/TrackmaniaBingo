use serde::{Deserialize, Serialize};
use serde_json::Value;

/// Basic incoming JSON message from a client. Only the `seq` and `req` fields are required.
#[derive(Deserialize, Debug)]
pub struct BaseRequest {
    #[serde(rename = "seq")]
    pub sequence: u32,
    #[serde(rename = "req")]
    pub request: String,
    #[serde(flatten)]
    pub fields: Value,
}

impl BaseRequest {
    pub fn build_response(&self, error: Option<String>, fields: Value) -> BaseResponse {
        BaseResponse {
            sequence: self.sequence,
            error,
            fields,
        }
    }
}

#[derive(Serialize, Debug)]
pub struct BaseResponse {
    #[serde(rename = "seq")]
    pub sequence: u32,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
    #[serde(flatten)]
    pub fields: Value,
}
