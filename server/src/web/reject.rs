use warp::reject;

#[derive(Debug)]
pub struct Forbidden;

impl reject::Reject for Forbidden {}

// async fn handle_rejection(err: Rejection) -> Result<impl Reply, std::convert::Infallible> {
//     Ok(reply::with_status(, status))
// }
