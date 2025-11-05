use std::marker::PhantomData;

use snowcap_api::widget::{container::Container, text::Text};

use crate::{
    signal::{Emitter, WithEmitter},
    widget::{State, WeakState, Widget, WidgetMessage, WithState, base::WidgetBase, signal},
};

pub struct Inner<Msg> {
    base: WidgetBase,
    content: String,
    _msg: PhantomData<Msg>,
}

#[derive(Clone)]
pub struct TextBox<Msg> {
    state: State<Inner<Msg>>,
}

#[derive(Clone)]
pub struct WeakTextBox<Msg>(WeakState<Inner<Msg>>);

impl<Msg> TextBox<Msg> {
    pub fn new(content: impl Into<String>) -> Self {
        let state = State::new(Inner {
            base: WidgetBase::new("TextBox"),
            content: content.into(),
            _msg: PhantomData,
        });

        Self { state }
    }

    pub fn get(&self) -> String {
        self.state.0.lock().unwrap().content.clone()
    }

    pub fn set(&mut self, content: impl Into<String>) {
        let mut state = self.state.0.lock().unwrap();
        state.content = content.into();
        state.emit(signal::RedrawNeeded);
    }

    pub fn downgrade(&self) -> WeakTextBox<Msg> {
        WeakTextBox(self.state.downgrade())
    }
}

impl<Msg> WeakTextBox<Msg> {
    pub fn upgrade(&self) -> Option<TextBox<Msg>> {
        self.0.upgrade().map(|state| TextBox { state })
    }
}

impl<Msg> Default for TextBox<Msg> {
    fn default() -> Self {
        Self::new("")
    }
}

impl<Msg> Widget for Inner<Msg>
where
    Msg: Clone + From<WidgetMessage>,
{
    type Message = Msg;

    fn view(&self) -> Option<snowcap_api::widget::WidgetDef<Self::Message>> {
        let widget = Container::new(Text::new(self.content.clone()));

        Some(widget.into())
    }
}

impl<Msg> WithEmitter for Inner<Msg> {
    fn with_emitter(&self) -> Emitter {
        self.base.with_emitter()
    }
}

impl<Msg> WithState for TextBox<Msg> {
    type Type = Inner<Msg>;

    fn with_state(&self) -> State<Self::Type> {
        self.state.clone()
    }
}
