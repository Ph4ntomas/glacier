//! Glacier's widgets
//!
//! Glacier supports two widgets flavor:
//!  - [`Functional`] are a simple wrapper around a view function, and can be used to quickly
//!    define stateless widget from a callback.
//!  - type implementing the [`Widget`] trait are stateful widget whose update function will be
//!    called with messaged from the underlying layer.
//!
//! Since it can be useful to hold a handle to the internal [`Widget`] state, the [`State`] type
//! allows widgets to delegate the implementation of `Widget` to the inner state, and the
//! [`WithState`] is used to recover said state in type accepting `Widget`.
//!
//! # Built-in widgets
//! Built-in [`Widget`] all implements the [`WithState`] trait, and internally uses
//! [`WidgetMessage`]. As such, when using built-in widget, you should implement
//! [`From<WidgetMessage>`] and [`Into<Option<WidgetMessage>>`] on your message type.
//!
//! Built-in [`Widget`] rendering function can be overridden. All built-in expose their default
//! function, which can be used from the overriding callback if you want to customize something
//! around the widget, instead of the widget itself. The widget module contains a public
//! `default_style()` function in case you want to tweak that instead of writing one from scratch.

use std::sync::{Arc, Mutex, Weak};

use snowcap_api::{popup::Parent, widget::WidgetDef};

use crate::signal::{Emitter, TryWithEmitter};

pub mod message;
pub mod operation;
pub mod signal;

//Widget Definitions
pub mod base;
pub mod clock;
pub mod prompt;
pub mod taglist;
pub mod textbox;

#[doc(inline)]
pub use clock::{Clock, LocalClock};
#[doc(inline)]
pub use prompt::Prompt;
#[doc(inline)]
pub use taglist::TagList;
#[doc(inline)]
pub use textbox::TextBox;

/// Message used by built-in widgets.
///
/// If your type can be used with built-in widget, it should be convertible to an from
/// [`WidgetMessage`] by implementing [`From<WidgetMessage>`] and [`Into<Option<WidgetMessage>>`].
#[derive(Clone, Debug)]
pub enum WidgetMessage {
    Operation(operation::Operation),
    TagList(taglist::Message),
    Prompt(prompt::Message),
}

/// Stateless, functional style widget.
///
/// This type is used as a disambiguation marker for stateless (view-only) widgets.
pub struct Functional<F, Msg>(pub F)
where
    F: Fn() -> WidgetDef<Msg> + Sync + Send + 'static;

/// Generic [`Widget`] state.
///
/// This type is a helper to build a stateful [`Widget`]
pub struct State<Inner>(Arc<Mutex<Inner>>);

/// Non owning version of the [`State`].
pub struct WeakState<Inner>(Weak<Mutex<Inner>>);

/// Trait to mark a type as containing a [`State`].
///
/// Implementing this trait allow object to be used as [`Widget`] by other constructs.
pub trait WithState {
    type Type;
    fn with_state(&self) -> State<Self::Type>;
}

/// Stateful `widget` trait.
pub trait Widget: TryWithEmitter {
    type Message: Clone;

    fn view(&self) -> Option<snowcap_api::widget::WidgetDef<Self::Message>>;

    fn update(&mut self, msg: Self::Message, parent: Option<Parent>) {
        let _ = msg;
        let _ = parent;
    }
}

impl<Inner> State<Inner> {
    /// Create a new widget state.
    pub fn new(inner: Inner) -> Self {
        Self(Arc::new(Mutex::new(inner)))
    }

    /// Create a [`WeakState`].
    pub fn downgrade(&self) -> WeakState<Inner> {
        WeakState(Arc::downgrade(&self.0))
    }
}

impl<Inner> WeakState<Inner> {
    /// Attempts to upgrade the `WeakState` to a `State`.
    ///
    /// Returns [`None`] if the inner value has since been dropped.
    pub fn upgrade(&self) -> Option<State<Inner>> {
        self.0.upgrade().map(State)
    }
}

impl<Inner> Clone for WeakState<Inner> {
    fn clone(&self) -> Self {
        Self(self.0.clone())
    }
}

impl<Inner> Clone for State<Inner> {
    fn clone(&self) -> Self {
        State(Arc::clone(&self.0))
    }
}

impl<Inner> TryWithEmitter for State<Inner>
where
    Inner: TryWithEmitter,
{
    fn try_with_emitter(&self) -> Option<Emitter> {
        self.0.lock().unwrap().try_with_emitter()
    }
}

impl<Inner> Widget for State<Inner>
where
    Inner: Widget,
{
    type Message = Inner::Message;

    fn view(&self) -> Option<snowcap_api::widget::WidgetDef<Self::Message>> {
        self.0.lock().unwrap().view()
    }

    fn update(&mut self, msg: Self::Message, parent: Option<Parent>) {
        self.0.lock().unwrap().update(msg, parent)
    }
}
