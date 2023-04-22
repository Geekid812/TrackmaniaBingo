use std::sync::{Arc, Mutex};

use generational_arena::Arena;
use rand::{distributions::Uniform, prelude::Distribution};
use tokio::{join, task};
use tracing::error;

use crate::{
    channel::ChannelCollection,
    client::{ClientId, GameClient},
    config::{self, JOINCODE_CHARS, JOINCODE_LENGTH},
    events::ServerEvent,
    gamedata::MapClaim,
    gamemap::{MapQuery, MapStock, Receiver, Sender},
    gameroom::{
        GameRoom, JoinRoomError, MapMode, Medal, NetworkPlayer, PlayerRef, RoomConfiguration,
        RoomIdentifier, RoomStatus,
    },
    gameteam::{GameTeam, TeamIdentifier},
    rest::auth::PlayerIdentity,
    sync::{build_sync_packet, SyncPacket},
};

pub struct GameServer {
    rooms: Mutex<Arena<GameRoom>>,
    channels: ChannelCollection,
    maps: MapStock,
}

impl GameServer {
    pub fn new(maps_tx: Sender) -> Self {
        let map_stock = MapStock::new(config::MAP_QUEUE_SIZE, maps_tx);
        Self {
            rooms: Mutex::new(Arena::new()),
            channels: ChannelCollection::new(),
            maps: map_stock,
        }
    }

    pub async fn spawn(self: Arc<Self>, maps_rx: Receiver) {
        join! { self.maps.fetch_loop(maps_rx) };
    }

    pub fn create_new_room(
        self: &Arc<Self>,
        config: RoomConfiguration,
        host: &GameClient,
    ) -> (PlayerRef, String, String, Vec<GameTeam>) {
        while self.find_room(&join_code).is_some() {
            join_code = (0..JOINCODE_LENGTH)
                .map(|_| JOINCODE_CHARS[uniform.sample(&mut rng)])
                .collect();
        }

        // Create room data structure
        let host_name = &host.identity().display_name;
        let mut room = GameRoom::create(
            format!(
                "{}{} Bingo game",
                host_name,
                if host_name.ends_with('s') { "'" } else { "'s" }
            ),
            join_code,
            config.clone(),
            self.channels.create_one(),
        );
        let room_name = room.name().to_owned();

        // Add the two starting teams and the host
        let team1 = room
            .create_team(self.channels.create_one())
            .expect("creating initial 1st team")
            .clone();
        let team2 = room
            .create_team(self.channels.create_one())
            .expect("creating initial 2nd team")
            .clone();
        let player_id = room
            .player_join(&host, true)
            .expect("adding host to a new room");
        self.channels.subscribe(room.channel(), host);

        let code = room.join_code().to_owned();
        let room_id = self.rooms.lock().expect("lock poisoned").insert(room);
        tokio::spawn(self.clone().load_maps(
            room_id,
            MapQuery::new(
                config.selection,
                config.grid_size as usize * config.grid_size as usize,
                config.mappack_id,
            ),
        ));
        ((room_id, player_id), room_name, code, vec![team1, team2])
    }

    async fn load_maps(self: Arc<Self>, room: RoomIdentifier, query: MapQuery) {
        let maps_result = self.maps.get_maps(&query).await;

        task::yield_now().await; // make sure we at least yield once (get_maps may not always yield)
        if let Some(room) = self.rooms.lock().expect("lock poisoned").get_mut(room) {
            match maps_result {
                Ok(maps) => {
                    // Check if map mode has changed during the load. If so, return the maps to the queue
                    if room.config().selection != query.mode {
                        self.maps.extend_maps(query.mode, maps);
                        return;
                    }

                    room.add_maps(maps);
                    self.channels
                        .broadcast(room.channel(), ServerEvent::MapsLoadResult { error: None })
                }
                Err(e) => {
                    error!("load_maps error: {}", e);
                    self.channels.broadcast(
                        room.channel(),
                        ServerEvent::MapsLoadResult {
                            error: Some(e.to_string()),
                        },
                    )
                }
            }
        }
    }

    pub fn edit_room_config(self: &Arc<Self>, room_id: RoomIdentifier, config: RoomConfiguration) {
        // TODO: handle errors
        if let Some(room) = self.rooms.lock().expect("lock poisoned").get_mut(room_id) {
            let old_grid_size = room.config().grid_size;
            let old_selection = room.config().selection;
            let old_mappack = room.config().mappack_id;
            room.set_config(config.clone());

            // Fetch / Remove maps if there was a config change in map mode.
            if config.selection != old_selection
                || (config.mappack_id.is_some() && config.mappack_id != old_mappack)
            {
                self.maps.extend_maps(old_selection, room.remove_all_maps());
                tokio::spawn(self.clone().load_maps(
                    room_id,
                    MapQuery::new(
                        config.selection,
                        (config.grid_size * config.grid_size) as usize,
                        config.mappack_id,
                    ),
                ));
            } else {
                let map_diff = usize::abs_diff(
                    config.grid_size as usize * config.grid_size as usize,
                    old_grid_size as usize * old_grid_size as usize,
                );
                if config.grid_size > old_grid_size {
                    tokio::spawn(self.clone().load_maps(
                        room_id,
                        MapQuery::new(config.selection, map_diff, config.mappack_id),
                    ));
                } else if config.grid_size < old_grid_size {
                    self.maps
                        .extend_maps(old_selection, room.remove_maps(map_diff));
                }
            }

            self.channels
                .broadcast(room.channel(), ServerEvent::RoomConfigUpdate(config));
        }
    }

    pub fn add_team(&self, room: RoomIdentifier) {
        if let Some(room) = self.rooms.lock().expect("lock poisoned").get_mut(room) {
            room.create_team(self.channels.create_one());
            self.channels
                .broadcast(room.channel(), ServerEvent::RoomUpdate(room.status()));
        }
    }

    pub fn change_team(&self, (room, player): PlayerRef, team: TeamIdentifier) {
        if let Some(room) = self.rooms.lock().expect("lock poisoned").get_mut(room) {
            room.change_team(player, team);
            self.channels
                .broadcast(room.channel(), ServerEvent::RoomUpdate(room.status()));
        }
    }

    fn find_room(&self, join_code: &str) -> Option<RoomIdentifier> {
        let lock = self.rooms.lock().expect("lock poisoned");
        let result = lock
            .iter()
            .filter(|(_, room)| room.join_code() == join_code)
            .next()?;
        Some(result.0)
    }

    pub fn join_room(
        &self,
        client: &GameClient,
        join_code: &str,
    ) -> Result<(PlayerRef, String, RoomConfiguration, RoomStatus), JoinRoomError> {
        let room_id = self
            .find_room(join_code)
            .ok_or(JoinRoomError::DoesNotExist(join_code.to_owned()))?;
        let mut lock = self.rooms.lock().expect("lock poisioned");
        let room = lock
            .get_mut(room_id)
            .ok_or(JoinRoomError::DoesNotExist(join_code.to_owned()))?;
        let player_id = room.player_join(client, false)?;
        let channel = room.channel();
        self.channels
            .broadcast(channel, ServerEvent::RoomUpdate(room.status()));
        self.channels.subscribe(channel, client);
        Ok((
            (room_id, player_id),
            room.name().to_owned(),
            room.config().clone(),
            room.status(),
        ))
    }

    pub fn disconnect(&self, id: ClientId, player: PlayerRef) {
        self.client_removed(id, player, false);
    }

    pub fn leave(&self, id: ClientId, player: PlayerRef) {
        self.client_removed(id, player, true);
    }

    fn client_removed(&self, id: ClientId, (room_id, player): PlayerRef, explicit: bool) {
        let mut lock = self.rooms.lock().expect("lock poisoned");
        if let Some(room) = lock.get_mut(room_id) {
            self.channels.unsubscribe(room.channel(), id);
            if let Some(team_id) = room.get_player(player).and_then(|p| p.team) {
                let team_channel = room.get_team(team_id).expect("team to exist").channel_id;
                self.channels.unsubscribe(team_channel, id);
            }

            if !explicit && room.has_started() {
                return;
            }

            let should_close = room.player_remove(player);
            if should_close {
                let room = lock.remove(room_id).expect("room exists");
                self.channels.remove(room.channel());
                for team in &room.teams() {
                    self.channels.remove(team.channel_id);
                }
            } else {
                self.channels
                    .broadcast(room.channel(), ServerEvent::RoomUpdate(room.status()));
            }
        }
    }

    pub fn start_game(&self, (room_id, _player): PlayerRef) {
        let mut lock = self.rooms.lock().expect("lock poisoned");
        if let Some(room) = lock.get_mut(room_id) {
            // TODO: check is operator
            room.set_started(true);
            self.channels.broadcast(
                room.channel(),
                ServerEvent::GameStart {
                    maps: room.maps().clone(),
                },
            );
        }
    }

    pub fn claim_cell(
        &self,
        (room_id, player_id): PlayerRef,
        map_uid: String,
        time: u64,
        medal: Medal,
    ) {
        let mut lock = self.rooms.lock().expect("lock poisoned");
        if let Some(room) = lock.get_mut(room_id) {
            if !room.has_started() {
                return;
            }
            if let Some(player) = room.get_player(player_id) {
                let claim = MapClaim {
                    player: NetworkPlayer::from(player),
                    time,
                    medal,
                };

                let cell_id = room.get_map(map_uid).unwrap().0; // TODO: avoid unwrap
                let cell = room
                    .get_cell_record(cell_id)
                    .expect("cells are correctly initialized");

                // unwrap here is safe because we check for none
                if cell.claim.is_none() || claim.time < cell.claim.as_ref().unwrap().time {
                    cell.claim = Some(claim.clone());

                    self.channels.broadcast(
                        room.channel(),
                        ServerEvent::CellClaim {
                            cell_id: cell_id,
                            claim: claim,
                        },
                    );

                    let bingos = room.check_for_bingos();
                    if bingos.len() > 0 {
                        self.channels.broadcast(
                            room.channel(),
                            ServerEvent::AnnounceBingo {
                                line: bingos[0].clone(),
                            },
                        );
                        room.set_started(false);
                    }
                }
            }
        }
    }

    pub fn sync_client(&self, (room_id, player_id): PlayerRef) -> Option<SyncPacket> {
        self.rooms
            .lock()
            .expect("lock poisoned")
            .get_mut(room_id)
            .and_then(|room| build_sync_packet(room, player_id))
    }

    pub fn resubscribe_client(&self, client: &GameClient, (room, player): PlayerRef) {
        if let Some(room) = self.rooms.lock().expect("lock poisoned").get(room) {
            self.channels.subscribe(room.channel(), client);
            if let Some(team) = room.get_player(player).and_then(|p| p.team) {
                let team_channel = room
                    .get_team(team)
                    .expect("teams should not be mismatched")
                    .channel_id;
                self.channels.subscribe(team_channel, client);
            }
        }
    }

    pub fn try_reconnect(&self, identity: &PlayerIdentity) -> Option<PlayerRef> {
        let rooms = self.rooms.lock().expect("lock poisoned");
        for (room_id, room) in rooms.iter() {
            let id_result = room.identify_player(identity);
            if let Some(player_id) = id_result {
                return Some((room_id, player_id));
            }
        }
        return None;
    }
}
