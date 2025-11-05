use std::sync::{Arc, Mutex, Weak};

use crate::signal::{Emitter, TryWithEmitter};

pub mod message;
pub mod operation;
pub mod signal;

//Widget Definitions
pub mod base;
pub mod clock;
pub mod prompt;
pub mod taglist;
pub mod textbox;

pub use clock::{Clock, LocalClock};
pub use prompt::Prompt;
pub use taglist::TagList;
pub use textbox::TextBox;

#[derive(Clone)]
pub enum WidgetMessage {
    Operation(operation::Operation),
    TagList(taglist::Message),
    Prompt(prompt::Message),
}

pub trait Widget: TryWithEmitter {
    type Message: Clone + From<WidgetMessage>;

    fn view(&self) -> Option<snowcap_api::widget::WidgetDef<Self::Message>>;

    fn update(&mut self, msg: Self::Message) {
        let _ = msg;
    }
}

pub struct State<Inner>(Arc<Mutex<Inner>>);

pub struct WeakState<Inner>(Weak<Mutex<Inner>>);

impl<Inner> Clone for WeakState<Inner> {
    fn clone(&self) -> Self {
        Self(self.0.clone())
    }
}

impl<Inner> WeakState<Inner> {
    pub fn upgrade(&self) -> Option<State<Inner>> {
        self.0.upgrade().map(State)
    }
}

impl<Inner> State<Inner> {
    pub fn new(inner: Inner) -> Self {
        Self(Arc::new(Mutex::new(inner)))
    }

    pub fn downgrade(&self) -> WeakState<Inner> {
        WeakState(Arc::downgrade(&self.0))
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

    fn view(&self) -> Option<snowcap_api::widget::WidgetDef<Self::Message>> {
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
