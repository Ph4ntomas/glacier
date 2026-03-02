//! Simple text display.
//!
//! [`TextBox`] widget allows to display simple text. `TextBox` can be updated through their
//! [`Handle`] or through [`Signal`] by using [`connect_to`] or [`connect_with`].
//!
//! When a `TextBox` content changes, it emit the [`ContentChanged`] signal, which can be used to
//! keep several `TextBox` in sync.
//!
//! The `TextBox` default [`Style`] support styling based on the `TextBox` content, and can be
//! replaced by a callback for more versatile styling.
//!
//! [`connect_to`]: TextBox::connect_to
//! [`connect_with`]: TextBox::connect_to

use std::marker::PhantomData;

use snowcap_api::{
    signal::{HandlerPolicy, Signal, Signaler, WeakSignaler},
    widget::{
        self, Alignment, Length, Program, WidgetDef,
        base::WidgetBase,
        container::Container,
        message::{Universal, UniversalMsg},
        text::Text,
    },
};

use crate::widget::errors::HandleError;

pub mod style;

use style::StyleInner;
#[doc(inline)]
pub use style::{ContentStyle, Style};

/// Signal emitted by [`TextBox`].
pub mod signal {
    use snowcap_api::signal::Signal;

    /// Emitted when a [`TextBox`] content changes.
    ///
    /// This event can be listened to by other TextBox to keep them in sync.
    ///
    /// [`TextBox`]: super::TextBox
    #[derive(Clone, Debug, Signal)]
    pub struct ContentChanged {
        pub content: String,
    }
}
use signal::ContentChanged;

type ViewCallback<Msg> = Box<dyn Fn(&str, ContentStyle) -> Option<WidgetDef<Msg>> + Send>;

#[derive(Clone, Debug)]
enum Action {
    Set(String),
    Emtpy,
}

/// Message updating the [`TextBox`] widget.
#[derive(Clone, Debug, Universal)]
struct Message {
    id: u32,
    action: Action,
}

/// `TextBox` widget.
///
/// See [module-level] documentation for more information.
///
/// [module-level]: self
pub struct TextBox<Msg> {
    base: WidgetBase,
    content: String,
    style: StyleInner,
    view_callback: Option<ViewCallback<Msg>>,
}

/// Handle to a [`TextBox`].
///
/// This handle can be used to change the content of the widget.
pub struct Handle<Msg> {
    id: u32,
    signaler: WeakSignaler,
    _data: PhantomData<fn() -> Msg>,
}

/// Default [`TextBox`] appearance.
pub fn default_style() -> Style {
    Style::default()
}

impl<Msg> TextBox<Msg> {
    const PROGRAM_NAME: &'static str = "TextBox";

    /// Create a new [`TextBox`] with default content & style.
    pub fn new() -> Self {
        Self::with_content("")
    }

    /// Create a new [`TextBox`] with the given content.
    pub fn with_content(content: impl Into<String>) -> Self {
        Self {
            base: WidgetBase::new(Self::PROGRAM_NAME),
            content: content.into(),
            style: default_style().into(),
            view_callback: None,
        }
    }

    /// Sets the [`TextBox`]'s [`Style`].
    pub fn style(self, style: Style) -> Self {
        Self {
            style: style.into(),
            ..self
        }
    }

    /// Sets a callback to use to generate [`ContentStyle`]s.
    pub fn style_callback<F>(self, callback: F) -> Self
    where
        F: Fn(&str) -> ContentStyle + Sync + Send + 'static,
    {
        Self {
            style: StyleInner::Callback(Box::new(callback)),
            ..self
        }
    }

    /// Sets a callback to replace the default view function.
    pub fn view_callback<F>(self, callback: F) -> Self
    where
        F: Fn(&str, ContentStyle) -> Option<WidgetDef<Msg>> + Send + 'static,
    {
        Self {
            view_callback: Some(Box::new(callback)),
            ..self
        }
    }

    /// Connect to this [`TextBox`] Signaler.
    pub fn connect<S, F>(&self, callback: F)
    where
        S: Signal,
        F: Fn(S) -> HandlerPolicy + Send + Sync + 'static,
    {
        self.base.signaler().connect(callback);
    }

    /// Emit a signal using the [`Signaler`].
    fn emit<Sig>(&self, signal: Sig)
    where
        Sig: Signal,
    {
        self.base.signaler().emit(signal)
    }
}

impl<Msg> TextBox<Msg>
where
    Msg: From<UniversalMsg> + Clone + Send + 'static,
{
    /// Connect the [`TextBox`] to a given signaler.
    ///
    /// The `TextBox` will connect to all standard [signal]. For arbitrary signal support, use
    /// [`connect_with`] instead.
    ///
    /// [`connect_with`]: TextBox::connect_with
    pub fn connect_to(&self, signaler: &Signaler) {
        signaler.connect({
            let handle = self.handle();
            move |ContentChanged { content }| {
                let Ok(_) = handle.set_content(content) else {
                    return HandlerPolicy::Discard;
                };

                HandlerPolicy::Keep
            }
        });
    }

    /// Connect the [`TextBox`] to a signaler, using the specified callback.
    ///
    /// This function can be used to connect the `TextBox` with an arbitrary signal.
    pub fn connect_with<S, F>(&self, signaler: &Signaler, callback: F)
    where
        S: Signal,
        F: Fn(S, Handle<Msg>) -> HandlerPolicy + Send + Sync + 'static,
    {
        signaler.connect({
            let handle = self.handle();
            move |s| callback(s, handle.clone())
        });
    }

    /// Create a new [`Handle`] for this textbox.
    pub fn handle(&self) -> Handle<Msg> {
        Handle {
            id: self.base.id(),
            signaler: self.base.signaler().downgrade(),
            _data: Default::default(),
        }
    }
}

impl<Msg> TextBox<Msg> {
    /// [`TextBox`] default view.
    pub fn default_view(
        content: impl Into<String>,
        mut style: ContentStyle,
    ) -> Option<WidgetDef<Msg>> {
        let padding = style.padding.take();

        let text = Text::new(content.into())
            .height(Length::Fill)
            .width(Length::Shrink)
            .vertical_alignment(Alignment::Center)
            .style(style.clone().into());

        let mut widget = Container::new(text)
            .height(Length::Fill)
            .width(Length::Shrink)
            .vertical_alignment(Alignment::Center)
            .style(style.into());

        widget.padding = padding;

        Some(widget.into())
    }
}

impl<Msg> Handle<Msg>
where
    Msg: From<UniversalMsg> + Clone + 'static,
{
    /// Set the [`TextBox`] content.
    pub fn set_content(&self, content: String) -> Result<(), HandleError> {
        self.send_message(Action::Set(content))
    }

    /// Empty the [`TextBox`].
    pub fn empty(&self) -> Result<(), HandleError> {
        self.send_message(Action::Emtpy)
    }

    /// Send a message to the [`TextBox`].
    fn send_message(&self, action: Action) -> Result<(), HandleError> {
        let Some(signaler) = self.signaler.upgrade() else {
            return Err(HandleError::Stale);
        };

        let message = Message {
            id: self.id,
            action,
        }
        .into_universal();

        signaler.emit(widget::signal::Message(Msg::from(message)));

        Ok(())
    }
}

impl<Msg> Default for TextBox<Msg> {
    fn default() -> Self {
        Self::new()
    }
}

impl<Msg> Clone for Handle<Msg> {
    fn clone(&self) -> Self {
        Self {
            id: self.id,
            signaler: self.signaler.clone(),
            _data: Default::default(),
        }
    }
}

impl<Msg> Program for TextBox<Msg>
where
    Msg: TryInto<UniversalMsg>,
{
    type Message = Msg;

    fn view(&self) -> Option<WidgetDef<Self::Message>> {
        let style = self.style.get(&self.content);

        if let Some(callback) = self.view_callback.as_ref() {
            callback(self.content.as_str(), style)
        } else {
            TextBox::default_view(self.content.as_str(), style)
        }
    }

    fn update(&mut self, msg: Self::Message) {
        let Ok(universal) = msg.try_into() else {
            return;
        };

        let action = match universal.downcast::<Message>() {
            Ok(Message { id, action }) if id == self.base.id() => action,
            _ => return,
        };

        let content = match action {
            Action::Set(mut content) => {
                std::mem::swap(&mut self.content, &mut content);
                content
            }
            Action::Emtpy => std::mem::take(&mut self.content),
        };

        if content != self.content {
            self.emit(signal::ContentChanged { content });
        }
    }

    fn signaler(&self) -> Option<snowcap_api::signal::Signaler> {
        Some(self.base.signaler())
    }
}
