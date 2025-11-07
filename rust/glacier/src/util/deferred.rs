use std::{
    sync::{Arc, Mutex, Weak},
    time::Duration,
};

use crate::{signal::HandlerPolicy, util::timer::Timer};

pub struct Inner {
    timer: Timer,
    fired: bool,
    callback: Box<dyn FnMut() + Send + Sync>,
}

pub struct Deferred {
    state: Arc<Mutex<Inner>>,
}

#[derive(Clone)]
pub struct WeakDeferred(Weak<Mutex<Inner>>);

pub fn defer<F>(callback: F) -> Deferred
where
    F: FnMut() + Send + Sync + 'static,
{
    let mut deferred = Deferred::new(callback, Duration::from_secs(0));
    deferred.start();
    deferred
}

pub fn defer_in<F>(callback: F, timeout: Duration) -> Deferred
where
    F: FnMut() + Send + Sync + 'static,
{
    let mut deferred = Deferred::new(callback, timeout);
    deferred.start();
    deferred
}

impl Deferred {
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

        timer.with_callback({
            let handle = defer.clone();
            move |_| {
                let mut inner = handle.state.lock().unwrap();
                (inner.callback)();
                inner.fired = true;

                HandlerPolicy::Discard
            }
        });

        defer
    }

    pub fn fired(&self) -> bool {
        self.state.lock().unwrap().fired
    }

    pub fn cancel(&mut self) {
        self.state.lock().unwrap().timer.stop();
    }

    pub fn start(&mut self) {
        self.state.lock().unwrap().timer.start(false);
    }

    pub fn downgrade(&self) -> WeakDeferred {
        WeakDeferred(Arc::downgrade(&self.state))
    }
}

impl WeakDeferred {
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
