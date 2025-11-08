//! Built-in [`Widget`] signals.
//!
//! [`Widget`]: super::Widget

use crate::signal::Signal;

/// Notify the containing layer that a redraw is needed.
#[derive(Clone, Copy, Debug, Signal)]
pub struct RedrawNeeded;

/// Request the containing layer to focus a [`Widget`]
///
/// [`Widget`]: super::Widget
#[derive(Clone, Debug, Signal)]
pub struct RequestFocus(pub String);

/// Request the containing layer to drop focus.
#[derive(Clone, Copy, Debug, Signal)]
pub struct RequestUnfocus;
