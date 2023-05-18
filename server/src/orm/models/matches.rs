use crate::core::util::serialize::serialize_time;
use crate::orm::schema::{matches, matches_players};
use chrono::NaiveDateTime;
use diesel::prelude::*;
use serde::Serialize;

use super::player::Player;

#[derive(Queryable, Selectable, Identifiable, Serialize)]
#[diesel(table_name = matches)]
#[diesel(primary_key(uid))]
pub struct Match {
    pub uid: i32,
    #[serde(serialize_with = "serialize_time")]
    pub started_at: NaiveDateTime,
    #[serde(serialize_with = "serialize_time")]
    pub ended_at: NaiveDateTime,
}

#[derive(Identifiable, Selectable, Queryable, Associations, Debug)]
#[diesel(belongs_to(Player, foreign_key = player_uid))]
#[diesel(belongs_to(Match, foreign_key = match_uid))]
#[diesel(table_name = matches_players)]
#[diesel(primary_key(player_uid, match_uid))]
pub struct PlayerToMatch {
    pub player_uid: i32,
    pub match_uid: i32,
}
