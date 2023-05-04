// @generated automatically by Diesel CLI.

diesel::table! {
    players (uid) {
        uid -> Integer,
        account_id -> Text,
        username -> Text,
        created_at -> Timestamp,
        score -> Integer,
        deviation -> Integer,
        country_code -> Text,
        client_token -> Nullable<Text>,
    }
}
