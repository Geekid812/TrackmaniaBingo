use pollster::block_on;
use serde::Deserialize;

use crate::{
    orm::{
        self,
        composed::daily::{self, DailyResults},
    },
    server::context::PlayerContext,
};

use super::{generic, Request, Response};

#[derive(Deserialize, Debug)]
pub struct GetDailyResults {
    period: String,
}

#[typetag::deserialize]
impl Request for GetDailyResults {
    fn handle(&self, _ctx: &mut PlayerContext) -> Box<dyn Response> {
        let time_period = self.period.clone();
        match block_on(orm::execute(move |mut conn| {
            block_on(daily::get_daily_results(&mut conn, &time_period))
        })) {
            Ok(results) => Box::new(results),
            Err(e) => Box::new(generic::Error {
                error: e.to_string(),
            }),
        }
    }
}

#[typetag::serialize]
impl Response for DailyResults {}
