use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::{
    core::{
        directory::MATCHES,
        models::{livegame::MatchState, team::TeamIdentifier},
    },
    server::{
        context::{ClientContext, GameContext},
        handlers::{error, response},
    },
};

#[derive(Deserialize, Debug)]
pub struct JoinMatch {
    uid: String,
    team_id: Option<TeamIdentifier>,
}

#[derive(Serialize, Debug)]
pub struct JoinMatchOk {
    pub state: MatchState,
}

pub fn handle(ctx: &mut ClientContext, args: JoinMatch) -> Value {
    if let Some(room) = ctx.game_room() {
        if !room.lock().match_uid().is_some_and(|uid| uid == args.uid) {
            ctx.trace("already joined a different room, leaving previous game");
            room.lock().player_remove(ctx.profile.uid);
        }
    }

    if let Some(livematch) = MATCHES.find(args.uid.clone()) {
        let mut lock = livematch.lock();
        if let Err(e) = lock.player_join(&ctx, args.team_id) {
            return error(&format!("{}", e));
        }

        let state = lock.get_state();
        drop(lock);

        ctx.game = Some(GameContext::new(ctx.profile.clone(), &livematch));

        response(JoinMatchOk { state })
    } else {
        error(&format!("match with uid {} not found", args.uid))
    }
}
