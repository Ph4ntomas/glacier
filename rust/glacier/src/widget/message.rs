//! Built-in [`WidgetMessage`]s utilities.

use std::marker::PhantomData;

use crate::widget::WidgetMessage;

/// Standard Widget message type.
#[derive(Clone, Debug)]
pub struct Message<Action> {
    /// [`WidgetBase`] id
    ///
    /// [`WidgetBase`]: crate::widget::base::WidgetBase
    pub id: u32,
    /// Custom action to execute on a call to `update`
    pub action: Action,
}

/// Utility type to build [`WidgetMessage`].
#[derive(Clone)]
pub struct MessageBuilder<Action> {
    id: u32,
    _msg: PhantomData<Action>,
}

impl<Action> MessageBuilder<Action>
where
    Message<Action>: Into<WidgetMessage>,
{
    /// Create a new builder for this a widget.
    pub fn new(id: u32) -> Self {
        Self {
            id,
            _msg: PhantomData,
        }
    }

    /// Build a [`WidgetMessage`] from an action.
    pub fn build(&self, action: Action) -> WidgetMessage {
        let id = self.id;
        Message { id, action }.into()
    }
}

impl<Action: Clone> Copy for MessageBuilder<Action> {}
