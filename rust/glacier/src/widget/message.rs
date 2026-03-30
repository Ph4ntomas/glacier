//! Built-in [`Message`]s utilities.

use std::marker::PhantomData;

use snowcap_api::widget::message::{Universal, UniversalMsg};

/// Standard Widget message type.
#[derive(Debug)]
pub struct Message<Event> {
    /// [`WidgetBase`] id
    ///
    /// [`WidgetBase`]: snowcap_api::widget::base::WidgetBase
    pub id: u32,
    /// Custom event to handle on a call to `update`
    pub event: Event,
}

/// Utility type to build [`UniversalMsg`].
pub struct MessageBuilder<Event> {
    id: u32,
    _msg: PhantomData<Event>,
}

impl<Event> MessageBuilder<Event>
where
    Event: Clone + Send + 'static,
    //Message<Event>: Universal
{
    /// Create a new builder for this a widget.
    pub fn new(id: u32) -> Self {
        Self {
            id,
            _msg: PhantomData,
        }
    }

    /// Build a [`UniversalMsg`] from an event.
    pub fn build(&self, event: Event) -> UniversalMsg {
        let id = self.id;

        Message { id, event }.into_universal()
    }
}

impl<Event> Clone for MessageBuilder<Event> {
    fn clone(&self) -> Self {
        *self
    }
}

impl<Event> Copy for MessageBuilder<Event> {}

impl<Event> Clone for Message<Event>
where
    Event: Clone,
{
    fn clone(&self) -> Self {
        Self {
            id: self.id,
            event: self.event.clone(),
        }
    }
}

impl<Event> Universal for Message<Event> where Event: Clone + Send + 'static {}
