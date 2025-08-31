use std::time::Duration;

use tokio::{spawn, time::sleep};

use crate::core::directory::Shared;

pub fn execute_delayed_task<T, F>(mutex: Shared<T>, callback: F, delay: Duration)
where
    T: Send + 'static,
    F: FnOnce(&mut T) + Send + 'static,
{
    spawn(async move {
        sleep(delay).await;
        if let Some(arg) = mutex.upgrade() {
            callback(&mut *arg.lock());
        }
    });
}

pub fn execute_repeating_task<T, F>(mutex: Shared<T>, callback: F, delay: Duration)
where
    T: Send + 'static,
    F: FnOnce(&mut T) + Send + Copy + 'static,
{
    spawn(async move {
        loop {
            sleep(delay).await;
            if let Some(arg) = mutex.upgrade() {
                callback(&mut *arg.lock());
            } else {
                break;
            }
        }
    });
}
