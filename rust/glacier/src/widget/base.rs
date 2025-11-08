//! Common widget base.

use std::{fmt::Display, sync::atomic::AtomicU32};

use crate::signal::{Emitter, WithEmitter};

/// Building block shared between all built-in widgets.
pub struct WidgetBase {
    widget_type: String,
    id: u32,
    emitter: Emitter,
}

static COUNT: AtomicU32 = AtomicU32::new(0);

fn next_id() -> u32 {
    COUNT.fetch_add(1, std::sync::atomic::Ordering::Relaxed)
}

impl WidgetBase {
    /// Create a new widget base, with a given type.
    pub fn new(widget_type: impl Into<String>) -> Self {
        Self {
            widget_type: widget_type.into(),
            id: next_id(),
            emitter: Emitter::default(),
        }
    }

    /// Get the widget base Id.
    pub fn id(&self) -> u32 {
        self.id
    }
}

impl Display for WidgetBase {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "<{}#{}>", self.widget_type, self.id)
    }
}

impl WithEmitter for WidgetBase {
    fn with_emitter(&self) -> Emitter {
        self.emitter.clone()
    }
}
