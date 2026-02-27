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
    ops::DerefMut,
    sync::{Arc, Mutex, Weak},
    time::Duration,
};

use snowcap_api::signal::{HandlerPolicy, Signal, Signaler};
use tokio::sync::mpsc;

#[derive(Clone, Copy)]
pub(crate) enum StopToken {
    Stop,
    Restart(bool),
}

type OnTimeoutCallback = Box<dyn Fn(&mut TimerData) + Send>;

pub struct TimerData {
    pub interval: Duration,
    pub repeat: bool,
    signaler: Signaler,
}

pub struct Inner {
    data: TimerData,
    on_timeout: Option<OnTimeoutCallback>,
    stop_token: Option<mpsc::UnboundedSender<StopToken>>,
}

/// Signal sent when a [`Timer`] starts.
#[derive(Clone, Signal)]
pub struct Started(pub Timer);

/// Signal sent when a [`Timer`] stops.
#[derive(Clone, Signal)]
pub struct Stopped(pub Timer);

/// Signal sent when a [`Timer`] timeout.
#[derive(Clone, Signal)]
pub struct Timeout(pub Timer);

/// Repeating, cancellable timer.
#[derive(Clone)]
pub struct Timer {
    handle: Arc<Mutex<Inner>>,
}

/// Non-owning reference to a timer.
#[derive(Clone)]
pub struct WeakTimer(Weak<Mutex<Inner>>);

impl Timer {
    /// Create a new repeating timer from a given interval and an existing Signaler.
    pub fn new_with_signaler(interval: Duration, signaler: Signaler) -> Self {
        let data = TimerData {
            interval,
            repeat: true,
            signaler,
        };

        let handle = Arc::new(Mutex::new(Inner {
            data,
            on_timeout: None,
            stop_token: None,
        }));

        Self { handle }
    }

    /// Create a new repeating timer from a given interval.
    pub fn new(interval: Duration) -> Self {
        Self::new_with_signaler(interval, Signaler::new())
    }

    pub fn once_with_signaler(timeout: Duration, signaler: Signaler) -> Self {
        let mut ret = Self::new_with_signaler(timeout, signaler);
        ret.repeat(false);

        ret
    }

    /// Create a non-repeating timer.
    pub fn once(timeout: Duration) -> Self {
        Self::once_with_signaler(timeout, Signaler::new())
    }

    /// Sets the timer interval.
    pub fn interval(&mut self, interval: Duration) {
        self.handle.lock().unwrap().data.interval = interval;
    }

    /// Make this timer repeating or non-repeating.
    pub fn repeat(&mut self, repeat: bool) {
        self.handle.lock().unwrap().data.repeat = repeat;
    }

    /// Connect a [`Signal`] handler to this timer.
    pub fn connect<Sig, F>(&mut self, callback: F)
    where
        Sig: Signal + Clone,
        F: Fn(Sig) -> HandlerPolicy + Send + Sync + 'static,
    {
        self.handle.lock().unwrap().data.signaler.connect(callback);
    }

    /// Set a callback to be called on timeout.
    ///
    /// The callback will be called with the [`TimerData`], allowing it to manage the current state
    /// or emit custom signals in addition to the standard Timeout.
    pub fn on_timeout<F>(&mut self, callback: F)
    where
        F: Fn(&mut TimerData) + Send + 'static,
    {
        self.handle.lock().unwrap().on_timeout = Some(Box::new(callback));
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

                handle.with_signaler(|s| s.emit(Started(handle.clone())));

                if now {
                    handle.process_timeout();
                }
            }

            loop {
                let Some(handle) = weak.upgrade() else {
                    return;
                };

                let interval = handle.with_data(|d| d.interval);

                let (timeout, restart) = match tokio::time::timeout(interval, recv.recv()).await {
                    Ok(Some(StopToken::Restart(now))) => (now, true),
                    Ok(None) | Ok(Some(StopToken::Stop)) => {
                        handle.with_data_mut(|data| data.repeat = false);
                        (false, false)
                    }
                    Err(_) => (true, false),
                };

                if timeout {
                    handle.process_timeout();
                }

                if handle.with_data(|d| !d.repeat) {
                    handle.with_signaler(|s| s.emit(Stopped(handle.clone())));
                    break;
                } else if restart {
                    handle.with_signaler(|s| s.emit(Started(handle.clone())));
                }
            }
        });
    }

    /// Stops this timer.
    pub fn stop(&self) {
        let mut guard = self.handle.lock().unwrap();

        if let Some(stopper) = guard.stop_token.take() {
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
        let guard = self.handle.lock().unwrap();

        if let Some(stopper) = &guard.stop_token {
            let _ = stopper.send(StopToken::Restart(now));
        } else {
            drop(guard);
            self.start(now);
        }
    }

    fn process_timeout(&self) {
        let mut guard = self.handle.lock().unwrap();
        let Inner {
            data, on_timeout, ..
        } = guard.deref_mut();

        data.signaler.emit(Timeout(self.clone()));

        if let Some(on_timeout) = on_timeout {
            on_timeout(data);
        }
    }

    fn with_signaler<F>(&self, processor: F)
    where
        F: FnOnce(&Signaler),
    {
        let guard = self.handle.lock().unwrap();

        processor(&guard.data.signaler)
    }

    fn with_data<F, Ret>(&self, processor: F) -> Ret
    where
        F: FnOnce(&TimerData) -> Ret,
    {
        let guard = self.handle.lock().unwrap();

        processor(&guard.data)
    }

    fn with_data_mut<F, Ret>(&self, processor: F) -> Ret
    where
        F: FnOnce(&mut TimerData) -> Ret,
    {
        let mut guard = self.handle.lock().unwrap();

        processor(&mut guard.data)
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

impl TimerData {
    pub fn signaler(&self) -> &Signaler {
        &self.signaler
    }
}
