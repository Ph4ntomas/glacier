use std::{
    sync::{Arc, Mutex, Weak},
    time::Duration,
};
use tokio::sync::mpsc;

use crate::signal::{Emitter, Signal, WithEmitter};

#[derive(Clone, Signal)]
pub struct Started(pub Timer);

#[derive(Clone, Signal)]
pub struct Stopped(pub Timer);

#[derive(Clone, Signal)]
pub struct Timeout(pub Timer);

#[derive(Clone, Copy)]
pub enum StopToken {
    Stop,
    Restart(bool),
}

pub struct Inner {
    interval: Duration,
    repeat: bool,
    emitter: Emitter,
    stop_token: Option<mpsc::UnboundedSender<StopToken>>,
}

#[derive(Clone)]
pub struct Timer {
    handle: Arc<Mutex<Inner>>,
}

#[derive(Clone)]
pub struct WeakTimer(Weak<Mutex<Inner>>);

impl WeakTimer {
    pub fn upgrade(&self) -> Option<Timer> {
        self.0.upgrade().map(|handle| Timer { handle })
    }
}

impl Timer {
    pub fn new(interval: Duration) -> Self {
        let handle = Arc::new(Mutex::new(Inner {
            interval,
            repeat: true,
            emitter: Emitter::default(),
            stop_token: None,
        }));

        Self { handle }
    }

    pub fn once(timeout: Duration) -> Self {
        let mut ret = Self::new(timeout);
        ret.repeat(false);

        ret
    }

    pub fn repeat(&mut self, repeat: bool) {
        self.handle.lock().unwrap().repeat = repeat;
    }

    pub fn with_callback<F>(&mut self, callback: F)
    where
        F: Fn(Timeout) -> bool + Send + Sync + 'static,
    {
        self.with_emitter().connect(callback);
    }

    pub fn downgrade(&self) -> WeakTimer {
        WeakTimer(Arc::downgrade(&self.handle))
    }

    pub fn start(&self, now: bool) {
        let (send, mut recv) = mpsc::unbounded_channel();

        self.handle.lock().unwrap().stop_token = Some(send);

        let weak = self.downgrade();
        tokio::spawn(async move {
            {
                let Some(handle) = weak.upgrade() else {
                    return;
                };

                handle.emit(Started(handle.clone()));

                if now {
                    handle.emit(Timeout(handle.clone()));
                }
            }

            loop {
                let Some(handle) = weak.upgrade() else {
                    return;
                };

                let mut stop = !handle.handle.lock().unwrap().repeat;
                let interval = handle.handle.lock().unwrap().interval;

                let (timeout, restart) = match tokio::time::timeout(interval, recv.recv()).await {
                    Ok(Some(StopToken::Restart(now))) => (now, true),
                    Ok(None) | Ok(Some(StopToken::Stop)) => {
                        stop = true;
                        (false, false)
                    }
                    Err(_) => (true, false),
                };

                if timeout {
                    handle.emit(Timeout(handle.clone()))
                }

                if stop {
                    handle.emit(Stopped(handle.clone()));
                    break;
                } else if restart {
                    handle.emit(Started(handle.clone()));
                }
            }
        });
    }

    pub fn stop(&self) {
        let inner = self.handle.lock().unwrap();

        if let Some(stopper) = &inner.stop_token {
            let _ = stopper.send(StopToken::Stop);
        }
    }

    pub fn restart(&self, now: bool) {
        let inner = self.handle.lock().unwrap();

        if let Some(stopper) = &inner.stop_token {
            let _ = stopper.send(StopToken::Restart(now));
        }
    }
}

impl WithEmitter for Timer {
    fn with_emitter(&self) -> Emitter {
        self.handle.lock().unwrap().emitter.clone()
    }
}
