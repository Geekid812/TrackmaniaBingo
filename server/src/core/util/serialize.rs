use chrono::NaiveDateTime;
use serde::{Serialize, Serializer};

pub fn serialize_time<S: Serializer>(
    time: &NaiveDateTime,
    serializer: S,
) -> Result<S::Ok, S::Error> {
    serializer.serialize_i64(time.and_utc().timestamp())
}

pub fn serialize_or_default<S: Serializer, T: Default + Serialize>(
    opt: &Option<T>,
    serializer: S,
) -> Result<S::Ok, S::Error> {
    match opt {
        None => T::default().serialize(serializer),
        Some(t) => t.serialize(serializer),
    }
}
