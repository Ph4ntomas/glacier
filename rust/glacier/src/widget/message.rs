use std::marker::PhantomData;

use crate::widget::WidgetMessage;

#[derive(Clone, Debug)]
pub struct Message<Action> {
    pub id: u32,
    pub action: Action,
}

#[derive(Clone)]
pub struct MessageBuilder<Action> {
    id: u32,
    _msg: PhantomData<Action>,
}

impl<Action: Clone> Copy for MessageBuilder<Action> {}

impl<Action> MessageBuilder<Action>
where
    Message<Action>: Into<WidgetMessage>,
{
    pub fn new(id: u32) -> Self {
        Self {
            id,
            _msg: PhantomData,
        }
    }

    pub fn build(&self, action: Action) -> WidgetMessage {
        let id = self.id;
        Message { id, action }.into()
    }
}
