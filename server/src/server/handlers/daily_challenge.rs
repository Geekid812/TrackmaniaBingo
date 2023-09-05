use serde::{Deserialize, Serialize};

use crate::{
    core::models::livegame::MatchState,
    server::{context::ClientContext, daily::DAILY_MATCH},
};

use super::{generic, Request, Response};

#[derive(Deserialize, Debug)]
pub struct SubscribeDailyChallenge;

#[derive(Serialize, Debug)]
pub struct DailyChallengeSync {
    pub state: MatchState,
}

#[derive(Serialize, Debug)]
pub struct DailyNotLoaded;

#[typetag::deserialize]
impl Request for SubscribeDailyChallenge {
    fn handle(&self, ctx: &mut ClientContext) -> Box<dyn Response> {
        let lock = DAILY_MATCH.lock();
        match lock.as_deref() {
            Some(challenge) => {
                let mut lock = challenge.lock();
                lock.channel()
                    .subscribe(ctx.profile.player.uid, ctx.writer.clone());
                let state = lock.get_state();
                Box::new(DailyChallengeSync { state })
            }
            None => Box::new(DailyNotLoaded),
        }
    }
}

#[derive(Deserialize, Debug)]
pub struct UnsubscribeDailyChallenge;

#[typetag::deserialize]
impl Request for UnsubscribeDailyChallenge {
    fn handle(&self, ctx: &mut ClientContext) -> Box<dyn Response> {
        let lock = DAILY_MATCH.lock();
        if let Some(challenge) = lock.as_deref() {
            challenge
                .lock()
                .channel()
                .unsubscribe(ctx.profile.player.uid);
            return Box::new(generic::Ok);
        }
        Box::new(generic::Error {
            error: "Daily not active".to_string(),
        })
    }
}

#[typetag::serialize]
impl Response for DailyChallengeSync {}

#[typetag::serialize]
impl Response for DailyNotLoaded {}
