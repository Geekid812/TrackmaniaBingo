use std::str::FromStr;

use reqwest::{Client, Url};
use serde::Deserialize;
use thiserror::Error;

use crate::config;
use crate::config::routes::tmexchange;
use crate::gamemap::GameMap;

pub async fn get_randomtmx(client: &Client) -> Result<GameMap, MapError> {
    get_maps(
        client,
        Url::from_str(&format!("{}{}", tmexchange::BASE, tmexchange::MAP_SEARCH))
            .expect("map search url to be valid"),
        &[
            ("api", "on"),
            ("random", "1"),
            ("mtype", "TM_Race"),
            ("etags", "23,37,40"),
            ("vehicles", "1"),
        ],
        |m| m.author_time <= config::MXRANDOM_MAX_AUTHOR_TIME,
    )
    .await
}

pub async fn get_totd(client: &Client) -> Result<GameMap, MapError> {
    get_maps(
        client,
        Url::from_str(&format!("{}{}", tmexchange::BASE, tmexchange::MAP_SEARCH))
            .expect("map search url to be valid"),
        &[("api", "on"), ("random", "1"), ("mode", "25")],
        |_| true,
    )
    .await
}

async fn get_maps<F>(
    client: &Client,
    url: Url,
    params: &[(&str, &str)],
    valid: F,
) -> Result<GameMap, MapError>
where
    F: Fn(&TMExchangeMap) -> bool,
{
    let map: MapsResult = client
        .get(url.clone())
        .query(params)
        .send()
        .await?
        .error_for_status()?
        .json()
        .await?;
    let tmxmap = map.results[0].clone();
    if !valid(&tmxmap) {
        return Err(MapError::Rejected(tmxmap));
    }
    Ok(tmxmap.into())
}

#[derive(Error, Debug)]
pub enum MapError {
    #[error(transparent)]
    Request(reqwest::Error),
    #[error("map is rejected per mapmode criterias")]
    Rejected(TMExchangeMap),
}

impl From<reqwest::Error> for MapError {
    fn from(value: reqwest::Error) -> Self {
        Self::Request(value)
    }
}

pub async fn get_mappack_tracks(
    client: &Client,
    tmxid: u32,
) -> Result<Vec<GameMap>, reqwest::Error> {
    let maps: Vec<TMExchangeMap> = client
        .get(
            Url::from_str(&format!(
                "{}{}{}",
                tmexchange::BASE,
                tmexchange::MAPPACK_MAPS,
                tmxid
            ))
            .expect("mappack url to be valid"),
        )
        .send()
        .await?
        .error_for_status()?
        .json()
        .await?;
    Ok(maps.into_iter().map(|m| m.into()).collect())
}

#[derive(Deserialize, Clone, Debug)]
#[serde(rename_all = "PascalCase")]
pub struct TMExchangeMap {
    #[serde(rename = "TrackID")]
    track_id: i64,
    #[serde(rename = "TrackUID")]
    track_uid: String,
    name: String,
    username: String,
    #[serde(rename = "AuthorTime")]
    author_time: i32,
}

impl Into<GameMap> for TMExchangeMap {
    fn into(self) -> GameMap {
        GameMap {
            track_id: self.track_id,
            uid: self.track_uid,
            name: self.name,
            author_name: self.username,
        }
    }
}

#[derive(Deserialize)]
struct MapsResult {
    results: [TMExchangeMap; 1],
}
