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

pub mod errors;
pub mod message;

//Widget Definitions
pub mod clock;
pub mod prompt;
pub mod systray;
pub mod taglist;
pub mod textbox;

pub mod utils;

#[doc(inline)]
pub use clock::{LocalSimpleClock, SimpleClock, UtcSimpleClock};
#[doc(inline)]
pub use prompt::Prompt;
#[doc(inline)]
pub use systray::SysTray;
#[doc(inline)]
pub use taglist::TagList;
#[doc(inline)]
pub use textbox::TextBox;
