// Load mappack maps from TrackmaniaExchange

use std::str::FromStr;

use anyhow::anyhow;
use reqwest::{
    header::{HeaderMap, HeaderValue},
    Client, Url,
};
use tracing::{debug, error};

use crate::{
    core::models::map::GameMap, integrations::USER_AGENT, orm::mapcache::record::MapRecord,
};

use super::{
    models::{MapResponse, MapsResponse},
    BASE,
};

const ROUTE_MAPPACK: &'static str = "/api/maps";

impl TryFrom<MapResponse> for MapRecord {
    type Error = anyhow::Error;

    fn try_from(value: MapResponse) -> Result<Self, Self::Error> {
        let primary_author = &value
            .authors
            .get(0)
            .ok_or(anyhow!("missing primary author when parsing MapResponse"))?
            .user;
        let style_name = value.tags.get(0).map(|tag| tag.name.clone());
        Ok(Self {
            uid: value.map_uid,
            tmxid: value.map_id,
            userid: primary_author.user_id,
            author_login: "".to_owned(), // Compatibility: This field is deprecated.
            username: primary_author.name.clone(),
            track_name: value.name,
            gbx_name: value.gbx_map_name,
            coppers: 0,     // Compatibility: This field is deprecated.
            author_time: 0, // Compatibility: This field is deprecated.
            uploaded_at: value.uploaded_at,
            updated_at: value.updated_at,
            tags: None, // Compatibility: This field is deprecated.
            style: style_name,
        })
    }
}

pub struct MappackLoader {
    client: Client,
}

impl MappackLoader {
    pub fn new() -> Self {
        let mut headers = HeaderMap::new();
        headers.insert("user-agent", HeaderValue::from_static(&USER_AGENT));
        Self {
            client: Client::builder()
                .default_headers(headers)
                .build()
                .expect("client should be built"),
        }
    }

    pub async fn get_mappack_tracks(
        &self,
        mappack_id: &str,
    ) -> Result<Vec<GameMap>, anyhow::Error> {
        let mut mappack_tracks = Vec::new();

        let (mut page_results, mut pagination_next_id) =
            self.paged_mappack_request_tracks(mappack_id, None).await?;
        mappack_tracks.append(&mut page_results);

        while pagination_next_id.is_some() {
            (page_results, pagination_next_id) = self
                .paged_mappack_request_tracks(mappack_id, pagination_next_id)
                .await?;
            mappack_tracks.append(&mut page_results);
        }

        Ok(mappack_tracks)
    }

    async fn paged_mappack_request_tracks(
        &self,
        mappack_id: &str,
        after_id: Option<i32>,
    ) -> Result<(Vec<GameMap>, Option<i32>), anyhow::Error> {
        let query_extra = after_id
            .map(|map_uid| format!("&after={}", map_uid))
            .unwrap_or_default();
        let url = Url::from_str(
            &format!("{}{}?mappackid={}{}&count=100&fields=MapId,MapUid,Name,GbxMapName,Authors[],UploadedAt,UpdatedAt,Tags[]", BASE, ROUTE_MAPPACK, mappack_id, query_extra)
        )?;
        debug!("requesting TMX tracks: {}", url);

        let response: MapsResponse = self
            .client
            .get(url)
            .send()
            .await?
            .error_for_status()?
            .json()
            .await?;

        let more = response.more;
        let maps: Vec<MapRecord> = response
            .results
            .into_iter()
            .map(MapRecord::try_from)
            .filter(|m| {
                if let Err(e) = m {
                    error!("invalid map loaded: {}", e);
                }
                m.is_ok()
            })
            .map(Result::unwrap) // Safety: Err has been filtered out above
            .collect();

        let next_id = if more {
            maps.last().map(|map| map.tmxid)
        } else {
            None
        };
        Ok((maps.into_iter().map(GameMap::TMX).collect(), next_id))
    }
}
