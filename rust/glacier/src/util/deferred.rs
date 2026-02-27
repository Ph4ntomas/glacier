use std::{
    sync::{Arc, Mutex, Weak},
    time::Duration,
};

use snowcap_api::signal::HandlerPolicy;

use crate::util::timer::{Timeout, Timer};

struct Inner {
    timer: Timer,
    fired: bool,
    callback: Box<dyn FnMut() + Send + Sync>,
}

/// Deferred function.
pub struct Deferred {
    state: Arc<Mutex<Inner>>,
}

/// Non-owning [`Deferred`].
#[derive(Clone)]
pub struct WeakDeferred(Weak<Mutex<Inner>>);

/// Defers a function with an timeout of 0.
///
/// This will effectively call the function after the current context.
pub fn defer<F>(callback: F) -> Deferred
where
    F: FnMut() + Send + Sync + 'static,
{
    let mut deferred = Deferred::new(callback, Duration::from_secs(0));
    deferred.start();
    deferred
}

/// Defers a function until after a giver `timeout`
pub fn defer_in<F>(callback: F, timeout: Duration) -> Deferred
where
    F: FnMut() + Send + Sync + 'static,
{
    let mut deferred = Deferred::new(callback, timeout);
    deferred.start();
    deferred
}

impl Deferred {
    /// Create a new [`Deferred`] function.
    pub fn new<F>(callback: F, timeout: Duration) -> Self
    where
        F: FnMut() + Send + Sync + 'static,
    {
        let mut timer = Timer::once(timeout);

        let inner = Inner {
            timer: timer.clone(),
            fired: false,
            callback: Box::new(callback),
        };

        let defer = Self {
            state: Arc::new(Mutex::new(inner)),
        };

        timer.connect({
            let handle = defer.clone();
            move |_: Timeout| {
                let mut inner = handle.state.lock().unwrap();
                (inner.callback)();
                inner.fired = true;

                HandlerPolicy::Discard
            }
        });

        defer
    }

    /// Check if the function fired.
    pub fn fired(&self) -> bool {
        self.state.lock().unwrap().fired
    }

    /// Cancel this deferred function by stopping its [`Timer`].
    pub fn cancel(&mut self) {
        self.state.lock().unwrap().timer.stop();
    }

    /// Start the [`Timer`] associated with this function.
    pub fn start(&mut self) {
        self.state.lock().unwrap().timer.start(false);
    }

    /// Create a [`WeakDeferred`] pointing to the same state.
    pub fn downgrade(&self) -> WeakDeferred {
        WeakDeferred(Arc::downgrade(&self.state))
    }
}

impl WeakDeferred {
    /// Attempt to upgrade this [`WeakDeferred`].
    ///
    /// Returns [`None`] if the [`Deferred`] was already dropped.
    pub fn upgrade(&self) -> Option<Deferred> {
        self.0.upgrade().map(|state| Deferred { state })
    }
}

impl Clone for Deferred {
    fn clone(&self) -> Self {
        Self {
            state: self.state.clone(),
        }
    }
}
