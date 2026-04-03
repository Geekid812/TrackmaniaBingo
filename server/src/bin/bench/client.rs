use std::sync::atomic::{AtomicU32, Ordering};
use std::time::Duration;

use anyhow::{anyhow, bail, Context, Result};
use bytes::BytesMut;
use futures::{SinkExt, StreamExt};
use tokio::net::TcpStream;
use tokio::time::timeout;
use tokio_util::codec::{Framed, LengthDelimitedCodec};

use crate::protocol::*;

const IO_TIMEOUT: Duration = Duration::from_secs(10);

#[allow(dead_code)]
pub struct BenchClient {
    framed: Framed<TcpStream, LengthDelimitedCodec>,
    seq: AtomicU32,
    pub player_id: String,
    pub display_name: String,
    /// Broadcasts received while waiting for a request response.
    broadcast_buf: Vec<BaseResponse>,
}

impl BenchClient {
    /// Connect to the server and complete the handshake.
    pub async fn connect(addr: &str, index: u32) -> Result<Self> {
        let account_id = format!("bench-{:08x}", index);
        let display_name = format!("bench-player-{:04}", index);

        let stream = timeout(IO_TIMEOUT, TcpStream::connect(addr))
            .await
            .context("connect timeout")?
            .context("connect failed")?;

        let codec = LengthDelimitedCodec::builder()
            .little_endian()
            .new_codec();
        let mut framed = Framed::new(stream, codec);

        // Step 1: KeyExchange -> TokenHint
        let kex = KeyExchangeRequest {
            key: String::new(),
            display_name: display_name.clone(),
            account_id: account_id.clone(),
        };
        send_msg(&mut framed, &kex).await?;
        let token_hint: TokenHint = recv_msg(&mut framed).await?;

        // Step 2: Handshake -> HandshakeResponse
        let hs = HandshakeRequest {
            version: "99.0".into(),
            game: 0,
            token: token_hint.token,
        };
        send_msg(&mut framed, &hs).await?;
        let hs_resp: HandshakeResponse = recv_msg(&mut framed).await?;

        if !hs_resp.success {
            bail!(
                "handshake rejected: {}",
                hs_resp.reason.unwrap_or_default()
            );
        }

        Ok(Self {
            framed,
            seq: AtomicU32::new(1),
            player_id: account_id,
            display_name,
            broadcast_buf: Vec::new(),
        })
    }

    /// Send a request and wait for the response with matching seq.
    pub async fn request<T: serde::Serialize>(
        &mut self,
        req_type: &str,
        fields: T,
    ) -> Result<BaseResponse> {
        let seq = self.seq.fetch_add(1, Ordering::Relaxed);
        let msg = BaseRequest {
            seq,
            req: req_type.to_string(),
            fields,
        };
        send_msg(&mut self.framed, &msg).await?;

        // Read messages until we get one with our seq.
        // Non-seq messages (broadcasts) are buffered for recv_any().
        loop {
            let resp: BaseResponse = recv_msg(&mut self.framed).await?;
            if resp.seq == Some(seq) {
                if let Some(ref err) = resp.error {
                    bail!("server error on {req_type}: {err}");
                }
                return Ok(resp);
            }
            // Buffer broadcasts so they aren't lost
            self.broadcast_buf.push(resp);
        }
    }

    /// Wait for the next incoming message (broadcast or response).
    /// Returns buffered broadcasts first (from messages received during request()).
    pub async fn recv_any(&mut self) -> Result<BaseResponse> {
        if !self.broadcast_buf.is_empty() {
            return Ok(self.broadcast_buf.remove(0));
        }
        recv_msg(&mut self.framed).await
    }

    /// Send a Ping request.
    pub async fn ping(&mut self) -> Result<BaseResponse> {
        self.request("Ping", PingFields {}).await
    }
}

async fn send_msg<T: serde::Serialize>(
    framed: &mut Framed<TcpStream, LengthDelimitedCodec>,
    msg: &T,
) -> Result<()> {
    let json = serde_json::to_string(msg)?;
    timeout(IO_TIMEOUT, framed.send(json.into()))
        .await
        .context("send timeout")?
        .context("send failed")
}

async fn recv_msg<T: serde::de::DeserializeOwned>(
    framed: &mut Framed<TcpStream, LengthDelimitedCodec>,
) -> Result<T> {
    let data: BytesMut = timeout(IO_TIMEOUT, framed.next())
        .await
        .context("recv timeout")?
        .ok_or_else(|| anyhow!("connection closed"))?
        .context("recv failed")?;
    let text = String::from_utf8(data.to_vec())?;
    serde_json::from_str(&text).with_context(|| format!("parse failed: {text}"))
}
