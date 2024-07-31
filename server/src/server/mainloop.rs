use bytes::BytesMut;
use serde::{Deserialize, Serialize};
use serde_json::from_str;

use super::client::NetClient;

type PeerId = usize;

/// Message handler for a connected client. This is the main message processing loop.
pub async fn mainloop_message_received(client: &mut NetClient, message: BytesMut) -> bool {
    let message = match String::from_utf8(message.to_vec()) {
        Ok(str) => str,
        Err(e) => {
            fault_connection(client, format!("could not decode utf-8 message: {}", e));
            return false;
        }
    };

    let frame: ServerFrame = match from_str(&message) {
        Ok(frame) => frame,
        Err(e) => {
            fault_connection(client, format!("could not parse incoming frame: {}", e));
            return false;
        }
    };

    // Do something
    true
}

/// Send a connection fault to the client with the specified message.
fn fault_connection(client: &mut NetClient, message: String) {
    client.messager().send(&ClientFrame::Error { message })
}

/// A JSON frame received by the server.
#[derive(Deserialize)]
#[serde(tag = "type")]
enum ServerFrame {
    Message { val: serde_json::Value },
}

/// A JSON frame received by the client.
#[derive(Serialize)]
#[serde(tag = "type")]
enum ClientFrame {
    Message {
        peer: PeerId,
        val: serde_json::Value,
    },
    Error {
        message: String,
    },
}
