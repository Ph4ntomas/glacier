//! Prompt widget
//!
//! [`Prompt`] are [`TextInput`] widgets that call a callback when submitted. The primary use-case
//! is to spawn some program, but that behavior can be overridden.
//!
//! By default, the widget is hidden, and only shown when the [`Prompt`] is activated by calling
//! its handle [`activate`] function. Upon activation, the prompt will be displayed, and request
//! focus from its underlying layer.
//!
//! [`activate`]: Handle::activate

use std::marker::PhantomData;

use crate::{
    color,
    widget::{
        errors::HandleError,
        message::{self, MessageBuilder},
    },
};

use snowcap_api::{
    signal::{HandlerPolicy, Signal, WeakSignaler},
    surface::SurfaceEvent,
    widget::{
        self, Alignment, Border, Length, Padding, Program,
        base::WidgetBase,
        container::Container,
        font,
        message::UniversalMsg,
        operation::focusable,
        text_input::{Icon, TextInput},
    },
};

pub mod style;
#[doc(inline)]
pub use style::{PromptStyle, Style};

type ExeCallback = Box<dyn FnMut(&str) + Send + 'static>;

pub mod signal {
    use snowcap_api::signal::Signal;

    #[derive(Debug, Clone, Signal)]
    pub struct Done(pub String);
}

#[derive(Clone, Debug)]
pub enum Event {
    Activate,
    Deactivate,
    Focus,
    Input(String),
    Submit,
}

pub type Message = message::Message<Event>;

/// Prompt widget.
///
/// See [module-level] documentation for more information.
///
/// [module-level]: self
pub struct Prompt<Msg> {
    base: WidgetBase,
    placeholder: String,
    content: String,
    style: Style,
    exe_callback: Option<ExeCallback>,
    active: bool,
    id: String,
    message_builder: MessageBuilder<Event>,
    _data: PhantomData<Msg>,
}

/// Handle to a [`Prompt`].
pub struct Handle<Msg> {
    id: u32,
    signaler: WeakSignaler,
    _data: PhantomData<Msg>,
}

/// Default [`Prompt`] execution callback.
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

/// Default [`Prompt`] appearance.
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

impl<Msg> Prompt<Msg> {
    const PROGRAM_NAME: &'static str = "Prompt";

    /// Create a new [`Prompt`]
    pub fn new() -> Self {
        let base = WidgetBase::new(Self::PROGRAM_NAME);
        let id = base.to_string();
        let message_builder = MessageBuilder::new(base.id());

        Self {
            base,
            placeholder: String::default(),
            content: String::default(),
            style: default_style(),
            exe_callback: None,
            active: false,
            id,
            message_builder,
            _data: PhantomData,
        }
    }

    /// Sets the [`Prompt`] style.
    pub fn style(self, style: Style) -> Self {
        Self { style, ..self }
    }

    /// Sets the [`Prompt`] placeholder.
    pub fn placeholder(self, placeholder: impl Into<String>) -> Self {
        Self {
            placeholder: placeholder.into(),
            ..self
        }
    }

    /// Sets the function to call when the prompt is submitted.
    pub fn exe_callback<F>(self, callback: F) -> Self
    where
        F: Fn(&str) + Send + 'static,
    {
        Self {
            exe_callback: Some(Box::new(callback)),
            ..self
        }
    }

    /// Gets a [`Handle`] to this [`Prompt`].
    pub fn handle(&self) -> Handle<Msg> {
        Handle {
            id: self.base.id(),
            signaler: self.base.signaler().downgrade(),
            _data: PhantomData,
        }
    }
}

impl<Msg> Handle<Msg>
where
    Msg: From<UniversalMsg> + Clone + 'static,
{
    /// Focus the [`Prompt`] referred to by this handle.
    pub fn focus(&self) -> Result<(), HandleError> {
        let Some(signaler) = self.signaler.upgrade() else {
            return Err(HandleError::Stale);
        };

        let builder = MessageBuilder::new(self.id);
        signaler.emit(widget::signal::Message(Msg::from(builder.focus())));
        Ok(())
    }

    /// Activate and focus the [`Prompt`].
    pub fn activate(&self) -> Result<(), HandleError> {
        let Some(signaler) = self.signaler.upgrade() else {
            return Err(HandleError::Stale);
        };

        let builder = MessageBuilder::new(self.id);
        signaler.emit(widget::signal::Message(Msg::from(builder.activate())));
        Ok(())
    }

    /// Decactivate the [`Prompt`].
    pub fn deactivate(&self) -> Result<(), HandleError> {
        let Some(signaler) = self.signaler.upgrade() else {
            return Err(HandleError::Stale);
        };

        let builder = MessageBuilder::new(self.id);
        signaler.emit(widget::signal::Message(Msg::from(builder.deactivate())));
        Ok(())
    }

    /// Connect to the [`Prompt`] signals.
    pub fn connect<S, F>(&self, callback: F) -> Result<snowcap_api::signal::Handle<S>, HandleError>
    where
        S: Signal,
        F: Fn(S) -> HandlerPolicy + Send + Sync + 'static,
    {
        let Some(signaler) = self.signaler.upgrade() else {
            return Err(HandleError::Stale);
        };

        Ok(signaler.connect(callback))
    }
}

impl<Msg> Prompt<Msg>
where
    Msg: From<UniversalMsg> + Clone + 'static,
{
    fn focus(&mut self) {
        if !self.active {
            return;
        }

        self.base.signaler().emit(focusable::focus(self.id.clone()));
    }

    fn activate(&mut self) {
        if self.active {
            return;
        }

        self.active = true;
        self.focus();
    }

    fn deactivate(&mut self) {
        if !self.active {
            return;
        }

        self.content.clear();
        self.active = false;
        self.base
            .signaler()
            .emit(signal::Done(self.base.to_string()));
    }
}

impl<Msg> Program for Prompt<Msg>
where
    Msg: From<UniversalMsg> + TryInto<UniversalMsg> + Clone + 'static,
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
                move |input| builder.input(input).into()
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
        let Some(universal) = msg.try_into().ok() else {
            return;
        };

        let event = match universal.downcast::<Message>() {
            Ok(message::Message { id, event }) if id == self.base.id() => event,
            _ => return,
        };

        match event {
            Event::Activate => self.activate(),
            Event::Deactivate => self.deactivate(),
            Event::Focus => self.focus(),
            Event::Input(s) => self.content = s,
            Event::Submit => {
                if let Some(callback) = self.exe_callback.as_mut() {
                    callback(&self.content)
                } else {
                    spawn(&self.content);
                }

                self.deactivate()
            }
        }
    }

    fn event(&mut self, event: snowcap_api::surface::SurfaceEvent<Self::Message>) {
        if let SurfaceEvent::FocusLost = event {
            self.deactivate();
        }
    }

    fn signaler(&self) -> Option<snowcap_api::signal::Signaler> {
        Some(self.base.signaler())
    }
}

impl<Msg> Default for Prompt<Msg> {
    fn default() -> Self {
        Self::new()
    }
}

impl<Msg> Clone for Handle<Msg> {
    fn clone(&self) -> Self {
        Self {
            id: self.id,
            signaler: self.signaler.clone(),
            _data: PhantomData,
        }
    }
}

impl MessageBuilder<Event> {
    fn activate(&self) -> UniversalMsg {
        self.build(Event::Activate)
    }

    fn deactivate(&self) -> UniversalMsg {
        self.build(Event::Deactivate)
    }

    fn focus(&self) -> UniversalMsg {
        self.build(Event::Focus)
    }

    fn input(&self, input: String) -> UniversalMsg {
        self.build(Event::Input(input))
    }

    fn submit(&self) -> UniversalMsg {
        self.build(Event::Submit)
    }
}
