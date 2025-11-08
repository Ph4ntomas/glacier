//!Utilities for synchronous signalling.
//!
//!Glacier provides a way to send informations between types in the form of [`Signal`]s. This can
//!be used to notify other object of property changes, and is used heavily by Glacier's
//![`widgets`] to notify the underlying Layer (e.g. [`Bar`]) that it need to be re-rendered.
//!
//!# Signals
//!A signal is an arbitrary type deriving from [`Signal`]. The only restriction on [`Signal`] is
//!that they must also derive from [`Clone`] to be emitted, since the signal will be duplicated to
//!every handlers.
//!
//!# Signal Emitter
//!
//!The [`Emitter`] type provides a building block to implement the signalling.
//!Other types can register callback by calling [`Emitter::connect`], and dispatch [`Signal`]
//!objects to any connected callback by calling [`Emitter::emit`]. The [`Emitter`] object is only
//!a handle an can be cloned. This is useful if you need to unlock a [`Mutex`] before sending a
//![`Signal`].
//!
//!The [`WithEmitter`] traits allows a type to delegate a few methods to their internal
//![`Emitter`]. [`WithEmitter::with_emitter`] should return a clone of the internal [`Emitter`].
//!
//![`TryWithEmitter`] can also be implemented for types that may or may not have an [`Emitter`], or
//!an internal object deriving from [`WithEmitter`]. Types that only want to connect to a signal
//!should prefer this type as their trait bounds.
//!
//!# Emitting Signals
//!
//!Calling [`WithEmitter::emit`], or [`Emitter::emit`] will dispatch the signal to every connected
//!handler for the specific [`Signal`]. Signal dispatch is synchronous, and should be done without
//!holding locks whenever possible.
//!
//!# Signal handler
//!
//!Signal handlers are simple callbacks that receive the [`Signal`] as their first parameter.
//!Handlers can be registered by calling [`Emitter::connect`] (or [`WithEmitter::connect`]), which
//!returns a [`Handle`] to disconnect the signal later on. Handlers return a [`HandlerPolicy`] to
//!indicate whether they should be kept, or can be discarded (e.g. because the handler is not
//!useful anymore, or should fire only once, or would extent the lifetime of another object).
//!
//![`Bar`]: crate::bar::Bar
//![`widgets`]: crate::widget
use std::{
    any::Any,
    collections::HashMap,
    sync::{Arc, Mutex, Weak},
};

pub use glacier_derive::Signal;

/// Signal trait
pub trait Signal {
    /// Name of the signal type.
    ///
    /// This value is used as a key, and should be unique.
    fn signal_name() -> &'static str;
}

/// Retention policy for signal handlers.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum HandlerPolicy {
    /// Keep the handler.
    Keep,
    /// Discard the handler.
    Discard,
}

/// Handle to disconnect a signal handler.
pub struct Handle<S: Signal>(Weak<dyn Fn(S) -> HandlerPolicy + Sync + Send>);

#[derive(Default, Clone)]
struct SignalEntry<S: Signal> {
    callbacks: Vec<Arc<dyn Fn(S) -> HandlerPolicy + Sync + Send>>,
}

/// Signal emitter.
///
/// [`Emitter`] holds handler for any signals in a type-erased way. Other types can
/// [connect] and [disconnect] handlers, or [emit] signals..
///
/// [connect]: Emitter::connect
/// [disconnect]: Emitter::disconnect
/// [emit]: Emitter::emit
#[derive(Default, Clone)]
pub struct Emitter {
    entries: Arc<Mutex<HashMap<String, Box<dyn Any + Sync + Send>>>>,
}

/// A trait to defer signal handling to an [`Emitter`].
///
/// Signal-enabled types should derive from this trait, as it provides a few convenience methods
/// to manage signals, as well as an automatic implementation of the [`TryWithEmitter`] trait.
pub trait WithEmitter {
    /// Return the internal [`Emitter`].
    fn with_emitter(&self) -> Emitter;

    /// Disconnect a [`Signal`] handler
    fn disconnect<S>(&mut self, handle: Handle<S>)
    where
        Self: Sized,
        S: Signal + Clone + 'static,
    {
        self.with_emitter().disconnect(handle);
    }

    /// Connect a handler to a specific [`Signal`]
    fn connect<S, F>(&mut self, callback: F) -> Handle<S>
    where
        Self: Sized,
        S: Signal + Clone + 'static,
        F: Fn(S) -> HandlerPolicy + Sync + Send + 'static,
    {
        self.with_emitter().connect(callback)
    }

    /// Emit a [`Signal`].
    fn emit<S>(&self, signal: S)
    where
        Self: Sized,
        S: Signal + Clone + 'static,
    {
        self.with_emitter().emit(signal)
    }
}

/// A trait for type that may not always have an [`Emitter`].
///
/// Type that may have additional functionality if other types have an [`Emitter`] but can function
/// without it should prefer dealing with implementation of this trait.
pub trait TryWithEmitter {
    /// Returns the [`Emitter`], if any.
    fn try_with_emitter(&self) -> Option<Emitter>;
}

impl Emitter {
    /// Create a new default [`Emitter`]
    pub fn new() -> Self {
        Self {
            entries: Arc::new(Mutex::new(HashMap::new())),
        }
    }

    /// Connect a signal handler.
    pub fn connect<S, F>(&mut self, callback: F) -> Handle<S>
    where
        S: Signal + Clone + 'static,
        F: Fn(S) -> HandlerPolicy + Sync + Send + 'static,
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

    /// Disconnect the signal handler referred to by `handle`.
    pub fn disconnect<S>(&mut self, handle: Handle<S>)
    where
        S: Signal + Clone + 'static,
    {
        let mut entries = self.entries.lock().unwrap();

        if let Some(entry) = Self::get_entry(&mut entries) {
            entry.remove_callback(handle);
        }
    }

    /// Disconnect all handler for a specific signal type.
    pub fn disconnect_all_for<S>(&mut self)
    where
        S: Signal + Clone + 'static,
    {
        let mut entries = self.entries.lock().unwrap();

        if let Some(entry) = Self::get_entry::<S>(&mut entries) {
            entry.clear()
        }
    }

    /// Disconnect all handlers.
    pub fn disconnect_all(&mut self) {
        self.entries.lock().unwrap().clear()
    }

    /// Emit a [`Signal`].
    pub fn emit<S>(&self, signal: S)
    where
        S: Signal + Clone + 'static,
    {
        let mut entries = self.entries.lock().unwrap();

        if let Some(entry) = Self::get_entry(&mut entries) {
            entry.emit(signal)
        }
    }

    /// Return the [`SignalEntry`] for a giver [`Signal`] type.
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
}

/// Internal type to hold a collection of handlers.
impl<S> SignalEntry<S>
where
    S: Signal + Clone,
{
    /// Create a new [`SignalEntry`]
    fn new() -> Self {
        Self {
            callbacks: Vec::new(),
        }
    }

    /// Add a callback to this [`SignalEntry`] and return a [`Handle`] to that callback.
    fn add_callback<F>(&mut self, callback: F) -> Handle<S>
    where
        F: Fn(S) -> HandlerPolicy + Sync + Send + 'static,
    {
        let callback: Arc<dyn Fn(S) -> HandlerPolicy + Sync + Send> = Arc::new(callback);

        let ret = Handle(Arc::downgrade(&callback));

        self.callbacks.push(callback);

        ret
    }

    /// Remove the callback the `handle` refers to.
    fn remove_callback(&mut self, handle: Handle<S>) {
        let Some(ptr) = handle.0.upgrade() else {
            return;
        };

        self.callbacks.retain(|cb| !Arc::ptr_eq(&ptr, cb));
    }

    /// Remove all handlers.
    fn clear(&mut self) {
        self.callbacks.clear();
    }

    /// Emits the `signal` by calling every handler, and remove the ones that need to be discarded.
    fn emit(&mut self, signal: S) {
        self.callbacks
            .retain_mut(|cb| cb(signal.clone()) == HandlerPolicy::Keep);
    }
}

impl<T: WithEmitter> TryWithEmitter for T {
    fn try_with_emitter(&self) -> Option<Emitter> {
        Some(self.with_emitter())
    }
}
