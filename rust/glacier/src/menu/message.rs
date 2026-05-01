use std::{fmt::Debug, marker::PhantomData};

use snowcap_api::widget::Point;

#[derive(Debug, Clone)]
pub enum Action {
    RefreshHover(Point),
    Next,
    Prev,
    Submit,
    MouseSubmit,
    OpenMenu,
    CloseSubmenu,
    Close,
}

#[derive(Clone, Copy, Debug)]
pub struct Builder<Msg> {
    id: u32,
    _data: PhantomData<fn() -> Msg>,
}

#[derive(Debug, Clone)]
pub enum Message {
    Menu { id: u32, action: Action },
    Entry(super::entry::Message),
}

impl<Msg> Builder<Msg> {
    pub fn new(id: u32) -> Self {
        Self {
            id,
            _data: PhantomData,
        }
    }
}

impl<Msg> Builder<Msg>
where
    Msg: From<Message>,
{
    pub(super) fn menu(&self, action: Action) -> Msg {
        Message::Menu {
            id: self.id,
            action,
        }
        .into()
    }
}
