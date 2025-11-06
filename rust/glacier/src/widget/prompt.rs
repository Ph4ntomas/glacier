use std::marker::PhantomData;

use snowcap_api::widget::{
    Alignment, Border, Length, Padding,
    container::Container,
    font,
    text_input::{Icon, TextInput},
};

use crate::{
    color,
    signal::WithEmitter,
    widget::{
        State, WeakState, Widget, WidgetMessage, WithState,
        base::WidgetBase,
        message::{self, MessageBuilder},
        operation, signal,
    },
};

pub mod style;
pub use style::{PromptStyle, Style};

#[derive(Clone)]
pub struct Prompt<Msg> {
    state: State<Inner<Msg>>,
}

#[derive(Clone)]
pub struct WeakPrompt<Msg>(WeakState<Inner<Msg>>);

pub struct Inner<Msg> {
    base: WidgetBase,
    placeholder: String,
    content: String,
    style: Style,
    active: bool,
    id: String,
    message_builder: MessageBuilder<Action>,
    _msg: PhantomData<Msg>,
}

#[derive(Clone, Debug)]
pub enum Action {
    Input(String),
    Submit,
}

pub type Message = message::Message<Action>;

pub fn default_style() -> Style {
    Style::new()
        .font(
            font::Font::new()
                .family(font::Family::Monospace)
                .weight(font::Weight::Semibold),
        )
        .icon(Icon::new().code_point('').spacing(4.0))
        .bg_color(color::from_hex_alpha("#000000", 0.0))
        .border(Border {
            width: Some(0.),
            ..Default::default()
        })
        .padding(Padding::from(0.))
}

impl<Msg> Prompt<Msg>
where
    Msg: Clone + Send + Sync + 'static,
{
    const WIDGET_TYPE: &'static str = "Prompt";

    pub fn new() -> Self {
        let base = WidgetBase::new(Self::WIDGET_TYPE);
        let id = base.to_string();
        let message_builder = MessageBuilder::new(base.id());

        let style = default_style();

        let state = State::new(Inner {
            base,
            placeholder: String::default(),
            content: String::default(),
            style,
            active: false,
            id,
            message_builder,
            _msg: PhantomData,
        });

        Self { state }
    }

    pub fn style(self, style: Style) -> Self {
        self.state.0.lock().unwrap().style = style;
        self.emit(signal::RedrawNeeded);
        self
    }

    pub fn deactivate(&mut self) {
        self.state.0.lock().unwrap().deactivate();
    }

    pub fn activate(&mut self) {
        self.state.0.lock().unwrap().activate();
    }

    pub fn unfocus(&mut self) {
        self.state.0.lock().unwrap().unfocus();
    }

    pub fn downgrade(&self) -> WeakPrompt<Msg> {
        WeakPrompt(self.state.downgrade())
    }

    pub fn spawn(input: &str) {
        if input.is_empty() {
            return;
        }

        let mut split = input.split_whitespace();

        let Some(cmd) = split.next() else {
            return;
        };

        pinnacle_api::process::Command::new(cmd).args(split).spawn();
    }
}

impl<Msg> WeakPrompt<Msg> {
    pub fn upgrade(&self) -> Option<Prompt<Msg>> {
        self.0.upgrade().map(|state| Prompt { state })
    }
}

impl<Msg> Default for Prompt<Msg>
where
    Msg: Clone + Send + Sync + 'static,
{
    fn default() -> Self {
        Self::new()
    }
}

impl<Msg> WithState for Prompt<Msg> {
    type Type = Inner<Msg>;

    fn with_state(&self) -> State<Self::Type> {
        self.state.clone()
    }
}

impl<Msg> Inner<Msg> {
    fn refresh(&mut self) {
        self.emit(signal::RedrawNeeded);
    }

    fn focus(&mut self) {
        self.emit(signal::RequestFocus(self.id.clone()));
    }

    fn reset(&mut self) {
        self.content.clear();
    }

    fn unfocus(&mut self) {
        self.emit(signal::RequestUnfocus);
    }

    fn activate(&mut self) {
        if self.active {
            return;
        }

        self.active = true;
        self.refresh();
        self.focus();
    }

    fn deactivate(&mut self) {
        self.reset();
        self.active = false;

        self.refresh();
    }

    fn on_input(builder: MessageBuilder<Action>, input: String) -> WidgetMessage {
        builder.input(input)
    }
}

impl<Msg> WithEmitter for Inner<Msg> {
    fn with_emitter(&self) -> crate::signal::Emitter {
        self.base.with_emitter()
    }
}

impl<Msg> WithEmitter for Prompt<Msg> {
    fn with_emitter(&self) -> crate::signal::Emitter {
        self.state.0.lock().unwrap().with_emitter()
    }
}

impl<Msg> Widget for Inner<Msg>
where
    Msg: Clone + From<WidgetMessage> + Into<Option<WidgetMessage>> + Send + Sync + 'static,
{
    type Message = Msg;

    fn view(&self) -> Option<snowcap_api::widget::WidgetDef<Self::Message>> {
        if !self.active {
            return None;
        }

        let mut inner = TextInput::new(&self.placeholder, &self.content)
            .id(&self.id)
            .on_input({
                let builder = self.message_builder;
                move |input| Self::on_input(builder, input).into()
            })
            .on_submit(self.message_builder.submit().into())
            .style(self.style.clone().into());

        inner.padding = self.style.padding;
        inner.font = self.style.font.clone();
        inner.icon = self.style.icon.clone();

        let prompt = Container::new(inner)
            .height(Length::Fill)
            .width(Length::Fill)
            .vertical_alignment(Alignment::Center);

        Some(prompt.into())
    }

    fn update(&mut self, msg: Self::Message) {
        use operation::{Focusable::Unfocus, Operation::Focusable};

        let Some(msg) = msg.into() else {
            return;
        };

        let action = match msg {
            WidgetMessage::Operation(Focusable(Unfocus)) => {
                self.deactivate();
                return;
            }
            WidgetMessage::Prompt(Message { id, action }) if id == self.base.id() => action,
            _ => {
                return;
            }
        };

        match action {
            Action::Input(s) => self.content = s,
            Action::Submit => {
                Prompt::<Msg>::spawn(&self.content);

                self.unfocus()
            }
        }
    }
}

impl From<Message> for WidgetMessage {
    fn from(value: Message) -> Self {
        Self::Prompt(value)
    }
}

impl MessageBuilder<Action> {
    fn input(&self, input: String) -> WidgetMessage {
        self.build(Action::Input(input))
    }

    fn submit(&self) -> WidgetMessage {
        self.build(Action::Submit)
    }
}
