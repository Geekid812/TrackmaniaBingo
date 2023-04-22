use futures::future::select;
use futures::pin_mut;
use std::io;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::tcp::{OwnedReadHalf, OwnedWriteHalf};
use tokio::net::TcpStream;
use tokio::sync::mpsc::{unbounded_channel, UnboundedReceiver, UnboundedSender};
use tracing::{debug, error};

use crate::config;

pub type SocketReader = UnboundedReceiver<String>;
pub type SocketWriter = UnboundedSender<SocketAction>;

pub enum SocketAction {
    Message(String),
    Stop,
}

pub fn spawn(socket: TcpStream) -> (SocketWriter, SocketReader) {
    let (write_tx, write_rx) = unbounded_channel();
    let (read_tx, read_rx) = unbounded_channel();
    tokio::spawn(run(socket, read_tx, write_rx));
    (write_tx, read_rx)
}

async fn run(
    socket: TcpStream,
    read_tx: UnboundedSender<String>,
    write_rx: UnboundedReceiver<SocketAction>,
) {
    let (reader, writer) = socket.into_split();
    let (rfut, wfut) = (read_loop(reader, read_tx), write_loop(writer, write_rx));
    pin_mut!(rfut, wfut);
    select(rfut, wfut).await;
}

async fn read_loop(mut reader: OwnedReadHalf, read_tx: UnboundedSender<String>) {
    loop {
        match recv(&mut reader).await {
            Ok(msg) => {
                if let Err(e) = read_tx.send(msg) {
                    error!("error in read sender: {:?}", e);
                    break;
                }
            }
            Err(e) if e.kind() == io::ErrorKind::UnexpectedEof => {
                debug!("socket disconnected");
                break;
            }
            Err(e) => {
                error!("read loop error: {:?}", e);
            }
        }
    }
}

async fn write_loop(mut writer: OwnedWriteHalf, mut write_rx: UnboundedReceiver<SocketAction>) {
    loop {
        match write_rx.recv().await {
            Some(action) => match action {
                SocketAction::Message(msg) => {
                    if let Err(e) = send(&mut writer, &msg).await {
                        error!("socket send error: {:?}", e);
                    }
                }
                SocketAction::Stop => {
                    debug!("received stop signal");
                    break;
                }
            },
            None => {
                error!("all socket senders were dropped");
                break;
            }
        }
    }
}

async fn recv(reader: &mut OwnedReadHalf) -> io::Result<String> {
    let mut buf = [0; 4];
    reader.read_exact(&mut buf).await?;
    let size = i32::from_le_bytes(buf);

    if size < 1 || size > config::MAXIMUM_PACKET_SIZE {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            format!("Invalid packet size: {}", size),
        ));
    }

    let mut msg_buf = vec![0; size as usize];
    reader.read_exact(&mut msg_buf).await?;
    let message =
        String::from_utf8(msg_buf).map_err(|e| io::Error::new(io::ErrorKind::InvalidData, e))?;
    Ok(message)
}

async fn send(writer: &mut OwnedWriteHalf, message: &str) -> io::Result<()> {
    let mut msg = (message.len() as i32).to_le_bytes().to_vec();
    msg.extend(message.as_bytes());
    writer.write_all(&msg).await?;
    Ok(())
}
