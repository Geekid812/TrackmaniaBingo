use tracing::{debug, warn};

use crate::context::{ClientContext, GameContext};
use crate::handlers::ClientEvent;
use crate::requests::BaseRequest;
use crate::rest::auth::PlayerIdentity;
use crate::socket::{SocketAction, SocketReader};

pub async fn run_loop(mut ctx: ClientContext, mut reader: SocketReader) -> LoopExit {
    loop {
        let data = reader.recv().await;
        if data.is_none() {
            // Client disconnected
            if let Some(game_ctx) = ctx.game {
                if game_ctx.room().map_or(false, |r| r.lock().has_started()) {
                    return LoopExit::Linger(ctx.identity, game_ctx);
                }
            }
            return LoopExit::Close;
        }
        let msg = data.unwrap();
        debug!("received: {}", msg);

        // Match a request
        if let Ok(incoming) = serde_json::from_str::<BaseRequest>(&msg) {
            let response = incoming.request.handle(&mut ctx);
            let outgoing = incoming.build_reply(response);
            let res_text = serde_json::to_string(&outgoing).expect("response serialization failed");
            debug!("response: {}", &res_text);
            let sent = ctx.writer.send(SocketAction::Message(res_text));
            if sent.is_err() {
                return LoopExit::Close; // Explicit disconnect
            }
        } else {
            // Match an event
            match serde_json::from_str::<Box<dyn ClientEvent>>(&msg) {
                Ok(event) => event.handle(&mut ctx),
                Err(e) => warn!("parse error: {:?}", e),
            };
        }
    }
}

pub enum LoopExit {
    Linger(PlayerIdentity, GameContext),
    Close,
}

// async fn handle_request(&mut self, variant: &Request) -> Response {
//     match variant {
//         Request::Ping => Response::Pong,
//         Request::CreateRoom(req) => {
//             let (player, name, join_code, teams) =
//                 self.server.create_new_room(req.config.clone(), &self);
//             self.player_id = Some(player);
//             Response::CreateRoom(CreateRoomResponse {
//                 name,
//                 join_code,
//                 teams,
//                 max_teams: TEAMS.len(),
//             })
//         }
//         Request::JoinRoom { join_code } => match self.server.join_room(&self, join_code) {
//             Ok((player, name, config, status)) => {
//                 self.player_id = Some(player);
//                 Response::JoinRoom {
//                     name,
//                     config: config,
//                     status: status,
//                 }
//             }
//             Err(e) => Response::Error {
//                 error: e.to_string(),
//             },
//         },
//         Request::EditRoomConfig { config } => {
//             if let Some((room, _)) = self.player_id {
//                 self.server.edit_room_config(room, config.clone());
//                 return Response::Ok;
//             }
//             Response::Error {
//                 error: "You are not in a room.".to_owned(),
//             }
//         }
//         Request::CreateTeam => {
//             if let Some((room, _)) = self.player_id {
//                 self.server.add_team(room);
//                 return Response::Ok;
//             }
//             Response::Error {
//                 error: "You are not in a room.".to_owned(),
//             }
//         }
//         Request::StartGame => {
//             self.server
//                 .start_game(self.player_id.expect("client is in a room"));
//             Response::Ok
//         }
//         Request::ClaimCell { uid, time, medal } => {
//             if let Some(player) = self.player_id {
//                 self.server.claim_cell(player, uid.clone(), *time, *medal);
//                 return Response::Ok;
//             }
//             Response::Error {
//                 error: "You are not in a room.".to_owned(),
//             }
//         }
//         Request::Sync => {
//             if self.player_id.is_none() {
//                 return Response::Error {
//                     error: "Sync failed, the game you joined may have ended already."
//                         .to_string(),
//                 };
//             }
//             match self.server.sync_client(self.player_id.unwrap()) {
//                 Some(sync) => Response::Sync(sync),
//                 None => Response::Error {
//                     error: "Sync error".to_string(),
//                 }, // TODO: handle results
//             }
//         }
//     }
// }
