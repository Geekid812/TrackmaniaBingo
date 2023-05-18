// @generated automatically by Diesel CLI.

diesel::table! {
    matches (uid) {
        uid -> Text,
        started_at -> Timestamp,
        ended_at -> Nullable<Timestamp>,
    }
}

diesel::table! {
    matches_players (player_uid, match_uid) {
        player_uid -> Integer,
        match_uid -> Text,
        outcome -> Nullable<Text>,
    }
}

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
        title -> Nullable<Text>,
    }
}

diesel::joinable!(matches_players -> matches (match_uid));
diesel::joinable!(matches_players -> players (player_uid));

diesel::allow_tables_to_appear_in_same_query!(
    matches,
    matches_players,
    players,
);
