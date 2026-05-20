use std::sync::Arc;
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::Duration;

use serde::Serialize;
use serde_json::to_vec;
use tokio::sync::mpsc::error::{SendTimeoutError, TrySendError};
use tracing::{error, trace, warn};

use crate::transport::TransportWriteQueue;

pub type NetMessager = Arc<NetMessageWriter>;

static DROPPED_MESSAGES: AtomicU64 = AtomicU64::new(0);
static DROPPED_BROADCASTS: AtomicU64 = AtomicU64::new(0);

pub fn take_drop_counts() -> (u64, u64) {
    (
        DROPPED_MESSAGES.swap(0, Ordering::Relaxed),
        DROPPED_BROADCASTS.swap(0, Ordering::Relaxed),
    )
}

pub fn new_messager(writer: TransportWriteQueue) -> NetMessager {
    Arc::new(NetMessageWriter::new(writer))
}

#[derive(Debug)]
pub struct NetMessageWriter {
    writer: TransportWriteQueue,
}

impl NetMessageWriter {
    pub fn new(writer: TransportWriteQueue) -> Self {
        Self { writer }
    }

    pub fn send<T: Serialize>(&self, message: &T) -> Result<(), Option<TrySendError<Vec<u8>>>> {
        let serialized = match to_vec(message) {
            Ok(message) => message,
            Err(e) => {
                error!("serilization failure: {}", e);
                return Err(None);
            }
        };

        match self.writer.try_send(serialized) {
            Ok(()) => Ok(()),
            Err(TrySendError::Full(_)) => {
                DROPPED_MESSAGES.fetch_add(1, Ordering::Relaxed);
                trace!("client channel full, dropping message");
                Ok(())
            }
            Err(e @ TrySendError::Closed(_)) => Err(Some(e)),
        }
    }

    pub async fn send_reliable<T: Serialize>(&self, message: &T) -> Result<(), ()> {
        let serialized = match to_vec(message) {
            Ok(message) => message,
            Err(e) => {
                error!("serilization failure: {}", e);
                return Err(());
            }
        };

        match self.writer.send_timeout(serialized, Duration::from_secs(5)).await {
            Ok(()) => Ok(()),
            Err(SendTimeoutError::Timeout(_)) => {
                warn!("client channel still full after 5s, dropping direct message");
                DROPPED_MESSAGES.fetch_add(1, Ordering::Relaxed);
                Err(())
            }
            Err(SendTimeoutError::Closed(_)) => Err(()),
        }
    }

    pub fn send_raw(&self, bytes: Vec<u8>) -> Result<(), Option<TrySendError<Vec<u8>>>> {
        match self.writer.try_send(bytes) {
            Ok(()) => Ok(()),
            Err(TrySendError::Full(_)) => {
                DROPPED_BROADCASTS.fetch_add(1, Ordering::Relaxed);
                Ok(())
            }
            Err(e @ TrySendError::Closed(_)) => Err(Some(e)),
        }
    }
}
