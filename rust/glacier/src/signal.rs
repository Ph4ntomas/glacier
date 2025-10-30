use std::{
    any::Any,
    collections::HashMap,
    sync::{Arc, Mutex, Weak},
};

pub use glacier_derive::Signal;

pub trait Signal {
    fn signal_name() -> &'static str;
}

pub struct Handle<S: Signal>(Weak<dyn Fn(S) -> bool + Sync + Send>);

#[derive(Default, Clone)]
struct SignalEntry<S: Signal> {
    callbacks: Vec<Arc<dyn Fn(S) -> bool + Sync + Send>>,
}

impl<S> SignalEntry<S>
where
    S: Signal + Clone,
{
    fn new() -> Self {
        Self {
            callbacks: Vec::new(),
        }
    }

    fn add_callback<F>(&mut self, callback: F) -> Handle<S>
    where
        F: Fn(S) -> bool + Sync + Send + 'static,
    {
        let callback: Arc<dyn Fn(S) -> bool + Sync + Send> = Arc::new(callback);

        let ret = Handle(Arc::downgrade(&callback));

        self.callbacks.push(callback);

        ret
    }

    fn remove_callback(&mut self, handle: Handle<S>) {
        let Some(ptr) = handle.0.upgrade() else {
            return;
        };

        self.callbacks.retain(|cb| !Arc::ptr_eq(&ptr, cb));
    }

    fn flush(&mut self) {
        self.callbacks.clear();
    }

    fn emit(&mut self, signal: S) {
        self.callbacks.retain_mut(|cb| !cb(signal.clone()));
    }
}

#[derive(Default, Clone)]
pub struct Emitter {
    entries: Arc<Mutex<HashMap<String, Box<dyn Any + Sync + Send>>>>,
}

impl Emitter {
    pub fn new() -> Self {
        Self {
            entries: Arc::new(Mutex::new(HashMap::new())),
        }
    }

    pub fn connect<S, F>(&mut self, callback: F) -> Handle<S>
    where
        S: Signal + Clone + 'static,
        F: Fn(S) -> bool + Sync + Send + 'static,
    {
        let key = S::signal_name();

        let mut entries = self.entries.lock().unwrap();

        let entry = entries
            .entry(key.into())
            .or_insert_with(|| Box::new(SignalEntry::<S>::new()))
            .downcast_mut::<SignalEntry<S>>()
            .expect("Could not retrieve entry");

        entry.add_callback(callback)
    }

    fn get_entry<S>(
        entries: &mut HashMap<String, Box<dyn Any + Sync + Send>>,
    ) -> Option<&mut SignalEntry<S>>
    where
        S: Signal + Clone + 'static,
    {
        entries
            .get_mut(S::signal_name())
            .and_then(|entry| entry.downcast_mut::<SignalEntry<S>>())
    }

    pub fn disconnect<S>(&mut self, handle: Handle<S>)
    where
        S: Signal + Clone + 'static,
    {
        let mut entries = self.entries.lock().unwrap();

        if let Some(entry) = Self::get_entry(&mut entries) {
            entry.remove_callback(handle);
        }
    }

    pub fn disconnect_all_for<S>(&mut self)
    where
        S: Signal + Clone + 'static,
    {
        let mut entries = self.entries.lock().unwrap();

        if let Some(entry) = Self::get_entry::<S>(&mut entries) {
            entry.flush()
        }
    }

    pub fn disconnect_all(&mut self) {
        self.entries.lock().unwrap().clear()
    }

    pub fn emit<S>(&self, signal: S)
    where
        S: Signal + Clone + 'static,
    {
        let mut entries = self.entries.lock().unwrap();

        if let Some(entry) = Self::get_entry(&mut entries) {
            entry.emit(signal)
        }
    }
}

pub trait WithEmitter {
    fn with_emitter(&self) -> Emitter;

    fn disconnect<S>(&mut self, handle: Handle<S>)
    where
        Self: Sized,
        S: Signal + Clone + 'static,
    {
        self.with_emitter().disconnect(handle);
    }

    fn connect<S, F>(&mut self, callback: F) -> Handle<S>
    where
        Self: Sized,
        S: Signal + Clone + 'static,
        F: Fn(S) -> bool + Sync + Send + 'static,
    {
        self.with_emitter().connect(callback)
    }

    fn emit<S>(&self, signal: S)
    where
        Self: Sized,
        S: Signal + Clone + 'static,
    {
        self.with_emitter().emit(signal)
    }
}

pub trait TryWithEmitter {
    fn try_with_emitter(&self) -> Option<Emitter>;
}

impl<T: WithEmitter> TryWithEmitter for T {
    fn try_with_emitter(&self) -> Option<Emitter> {
        Some(self.with_emitter())
    }
}
