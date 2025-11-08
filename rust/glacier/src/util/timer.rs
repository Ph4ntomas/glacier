//! Repeating, cancellable timers.
//!
//! Glacier's [`Timer`]s allows to periodically emit [`Signal`].
//!
//! When a `Timer` starts, it emit a [`Started`] signal containing a handle to this timer.
//! When it stops a [`Stopped`] signal is emitted.
//!
//! By default, [`Timer`]s repeat in a loop until stopped, emitting a [`Timeout`] every-time they
//! expires.

use std::{
    sync::{Arc, Mutex, Weak},
    time::Duration,
};
use tokio::sync::mpsc;

use crate::signal::{Emitter, HandlerPolicy, Signal, WithEmitter};

/// Signal sent when a [`Timer`] starts.
#[derive(Clone, Signal)]
pub struct Started(pub Timer);

/// Signal sent when a [`Timer`] stops.
#[derive(Clone, Signal)]
pub struct Stopped(pub Timer);

/// Signal sent when a [`Timer`] timeout.
#[derive(Clone, Signal)]
pub struct Timeout(pub Timer);

#[derive(Clone, Copy)]
enum StopToken {
    Stop,
    Restart(bool),
}

struct Inner {
    interval: Duration,
    repeat: bool,
    emitter: Emitter,
    stop_token: Option<mpsc::UnboundedSender<StopToken>>,
}

/// Repeating, cancellable timer.
#[derive(Clone)]
pub struct Timer {
    handle: Arc<Mutex<Inner>>,
}

/// Non-owning reference to a timer.
#[derive(Clone)]
pub struct WeakTimer(Weak<Mutex<Inner>>);

impl Timer {
    /// Create a new repeating timer, from a given interval.
    pub fn new(interval: Duration) -> Self {
        let handle = Arc::new(Mutex::new(Inner {
            interval,
            repeat: true,
            emitter: Emitter::default(),
            stop_token: None,
        }));

        Self { handle }
    }

    /// Create a non-repeating timer.
    pub fn once(timeout: Duration) -> Self {
        let mut ret = Self::new(timeout);
        ret.repeat(false);

        ret
    }

    /// Sets the timer interval.
    pub fn interval(&mut self, interval: Duration) {
        self.handle.lock().unwrap().interval = interval;
    }

    /// Make this timer repeating or non-repeating.
    pub fn repeat(&mut self, repeat: bool) {
        self.handle.lock().unwrap().repeat = repeat;
    }

    /// Connect a handler to this timer.
    pub fn with_callback<F>(&mut self, callback: F)
    where
        F: Fn(Timeout) -> HandlerPolicy + Send + Sync + 'static,
    {
        self.with_emitter().connect(callback);
    }

    /// Create a [`WeakTimer`] from this timer.
    pub fn downgrade(&self) -> WeakTimer {
        WeakTimer(Arc::downgrade(&self.handle))
    }

    /// Starts the timer.
    ///
    /// If `now` is set, a [`Timeout`] signal is sent right after the [`Started`] signal.
    ///
    /// Calling start on a running timer does nothing.
    pub fn start(&self, now: bool) {
        if self.handle.lock().unwrap().stop_token.is_some() {
            return;
        }

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

    /// Stops this timer.
    pub fn stop(&self) {
        let mut inner = self.handle.lock().unwrap();

        if let Some(stopper) = inner.stop_token.take() {
            let _ = stopper.send(StopToken::Stop);
        }
    }

    /// Restart this timer.
    ///
    /// This is similar to calling [`stop`] followed by [`start`], except it won't emit a
    /// [`Stopped`] signal if the timer was running.
    ///
    /// [`stop`]: Timer::stop
    /// [`start`]: Timer::start
    pub fn restart(&self, now: bool) {
        let inner = self.handle.lock().unwrap();

        if let Some(stopper) = &inner.stop_token {
            let _ = stopper.send(StopToken::Restart(now));
        } else {
            drop(inner);
            self.start(now)
        }
    }
}

impl WeakTimer {
    /// Attempts to upgrade the `WeakTimer` to a [`Timer`].
    ///
    /// Returns [`None`] if the timer was already dropped.
    pub fn upgrade(&self) -> Option<Timer> {
        self.0.upgrade().map(|handle| Timer { handle })
    }
}

impl WithEmitter for Timer {
    fn with_emitter(&self) -> Emitter {
        self.handle.lock().unwrap().emitter.clone()
    }
}
