// This schema is not automatically synchronized.
// It must be manually updated when the schema of mapcache.db changes.

diesel::table! {
    maps (tmxid) {
        tmxid -> Integer,
        uid -> Nullable<Text>,
        userid -> Integer,
        author_login -> Text,
        username -> Text,
        track_name -> Text,
        gbx_name -> Text,
        coppers -> Integer,
        author_time -> Integer,
        uploaded_at -> Timestamp,
        updated_at -> Timestamp,
        tags -> Nullable<Text>,
        style -> Nullable<Text>,
    }
}
