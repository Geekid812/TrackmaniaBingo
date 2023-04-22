use std::sync::{Arc, Weak};

use crate::socket::SocketWriter;

#[derive(Clone)]
pub enum WriteSink {
    Direct(Weak<SocketWriter>),
    Double(Weak<Weak<SocketWriter>>),
}

impl WriteSink {
    pub fn writer(&self) -> Option<Arc<SocketWriter>> {
        match self {
            Self::Direct(writer) => writer.upgrade(),
            Self::Double(writer) => writer.upgrade().and_then(|arc| arc.upgrade()),
        }
    }

    pub fn is_alive(&self) -> bool {
        match self {
            Self::Direct(writer) => writer.strong_count() > 0,
            Self::Double(writer) => writer.strong_count() > 0,
        }
    }
}
