use chrono::NaiveDateTime;
use serde::Serializer;

pub fn serialize_time<S: Serializer>(
    time: &NaiveDateTime,
    serializer: S,
) -> Result<S::Ok, S::Error> {
    serializer.serialize_i64(time.timestamp())
}
