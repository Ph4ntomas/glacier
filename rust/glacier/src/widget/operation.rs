//! Built-in [`Widget`] operation
//!
//! [`Widget`]: super::Widget

/// Operation acting on widget that may gain focus.
#[derive(Debug, Clone)]
pub enum Focusable {
    /// Focus a widget with a given server-side id.
    Focus(String),
    /// Unfocus all widgets.
    Unfocus,
}

/// Common type for all operations.
#[derive(Debug, Clone)]
pub enum Operation {
    /// Operation targeting focusable widgets.
    Focusable(Focusable),
}

impl From<Focusable> for Operation {
    fn from(value: Focusable) -> Self {
        Self::Focusable(value)
    }
}
