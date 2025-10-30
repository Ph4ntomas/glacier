use std::sync::{Arc, Mutex};

use crate::signal::{Emitter, TryWithEmitter};

pub mod signal;

//Widget Definitions
pub mod base;
pub mod textbox;

pub use textbox::TextBox;

#[derive(Clone)]
pub enum WidgetMessage {}

pub trait Widget: TryWithEmitter {
    type Message: Clone + From<WidgetMessage>;

    fn view(&self) -> snowcap_api::widget::WidgetDef<Self::Message>;
    fn update(&mut self, msg: Self::Message) {
        let _ = msg;
    }
}

pub struct State<Inner>(Arc<Mutex<Inner>>);

impl<Inner> State<Inner> {
    fn new(inner: Inner) -> Self {
        Self(Arc::new(Mutex::new(inner)))
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

    fn view(&self) -> snowcap_api::widget::WidgetDef<Self::Message> {
        self.0.lock().unwrap().view()
    }

    fn update(&mut self, msg: Self::Message) {
        self.0.lock().unwrap().update(msg)
    }
}

pub trait WithState {
    type Type;
    fn with_state(&self) -> State<Self::Type>;
}
