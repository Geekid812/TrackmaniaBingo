use futures::{FutureExt, StreamExt};
use std::io;
use tokio::select;
use tracing::{debug, error, warn};

use super::requests::BaseRequest;
use crate::server::context::ClientContext;
use crate::transport::client::tcpnative::TcpNativeClient;

pub async fn run_loop(mut ctx: ClientContext, mut client: TcpNativeClient) {
    loop {
        let next_message = client.inner.next().fuse();
        let next_sending = client.rx.recv().fuse();
        select! {
            opt = next_message => match opt {
                Some(result) => {
                    if !handle_recv(&mut ctx, result) {
                        return;
                    }
                },
                None => {
                    error!("Client has explicitly disconnected");
                    return;
                }
            },
            write_data = next_sending => match write_data {
                Some(data) => {
                    client.write(data).await;
                },
                None => {
                    error!("Connection close requested by server");
                    return;
                },
            }
        };
    }
}

fn handle_recv(ctx: &mut ClientContext, result: Result<String, io::Error>) -> bool {
    let msg = match result {
        Ok(msg) => msg,
        Err(e) => return false,
    };
    debug!("received: {}", msg);

    // Match a request
    match serde_json::from_str::<BaseRequest>(&msg) {
        Ok(incoming) => {
            let response = incoming.request.handle(ctx);
            let outgoing = incoming.build_reply(response);
            let res_text = serde_json::to_string(&outgoing).expect("response serialization failed");
            debug!("response: {}", &res_text);
            let sent = ctx.writer.send(res_text);
            if sent.is_err() {
                return false; // Explicit disconnect
            }
        }
        Err(e) => warn!("Unknown message received: {e}"),
    };
    true
}
