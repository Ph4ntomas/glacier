use std::{
    any::Any,
    fmt::Debug,
    marker::PhantomData,
    sync::{Arc, Mutex},
};

use snowcap_api::widget::Point;

#[derive(Clone)]
pub struct InFlightMenu(Arc<Mutex<Option<Box<dyn Any + Send>>>>);

impl InFlightMenu {
    pub fn new<Msg>(menu: super::Menu<Msg>) -> Self
    where
        Msg: Send + 'static,
    {
        Self(Arc::new(Mutex::new(Some(Box::new(menu)))))
    }

    pub fn take<Msg>(self) -> Option<super::Menu<Msg>>
    where
        Msg: 'static,
    {
        let any = self.0.lock().unwrap().take()?;
        any.downcast().map(|m| *m).ok()
    }
}

#[derive(Debug, Clone)]
pub enum Action {
    RefreshHover(Point),
    Next,
    Prev,
    Submit,
    MouseSubmit,
    OpenMenu,
    OpenSubmenu(InFlightMenu),
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

    //pub(super) fn entry(&self, msg: super::entry::Message) -> Msg {
    //Message::Entry(msg).into()
    //}
}

impl Debug for InFlightMenu {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_tuple("InFlightMenu").finish_non_exhaustive()
    }
}

impl<Msg> From<super::Menu<Msg>> for InFlightMenu
where
    Msg: Send + 'static,
{
    fn from(value: super::Menu<Msg>) -> Self {
        InFlightMenu(Arc::new(Mutex::new(Some(Box::new(value)))))
    }
}
