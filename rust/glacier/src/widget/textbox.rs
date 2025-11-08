//! TextBox widget
//!
//! [`TextBox`] widget allows to display simple text. When the text contained in the `TextBox` is
//! updated, the widget will emit a [`RedrawNeeded`] signal to notify the containing layer that it
//! need to be re-rendered.
//!
//! The `TextBox` default [`Style`] support styling based on the `TextBox` content, and can be
//! replaced by a callback for more versatile styling.
//!
//! [`RedrawNeeded`]: crate::widget::signal::RedrawNeeded

use snowcap_api::widget::{Alignment, Length, WidgetDef, container::Container, text::Text};

use crate::{
    signal::{Emitter, WithEmitter},
    widget::{State, WeakState, Widget, WidgetMessage, WithState, base::WidgetBase, signal},
};

pub mod style;

use style::StyleInner;
#[doc(inline)]
pub use style::{ContentStyle, Style};

type ViewCallback<Msg> =
    Box<dyn Fn(&str, ContentStyle) -> Option<WidgetDef<Msg>> + Send + Sync + 'static>;

/// [`TextBox`] inner state.
pub struct Inner<Msg> {
    base: WidgetBase,
    content: String,
    style: StyleInner,
    view_callback: Option<ViewCallback<Msg>>,
}

/// TextBox widget.
#[derive(Clone)]
pub struct TextBox<Msg> {
    state: State<Inner<Msg>>,
}

/// Non-owning version of a [`TextBox`].
#[derive(Clone)]
pub struct WeakTextBox<Msg>(WeakState<Inner<Msg>>);

/// Default [`TextBox`] appearance.
pub fn default_style() -> Style {
    Style::default()
}

impl<Msg> TextBox<Msg> {
    /// Create a new [`TextBox`] with default content & style.
    pub fn new() -> Self {
        Self::default()
    }

    /// Create a new [`TextBox`] with the given content.
    pub fn with_content(content: impl Into<String>) -> Self {
        let state = State::new(Inner {
            base: WidgetBase::new("TextBox"),
            content: content.into(),
            style: default_style().into(),
            view_callback: None,
        });

        Self { state }
    }

    /// Sets the [`TextBox`]'s [`Style`].
    pub fn style(self, style: Style) -> Self {
        self.state.0.lock().unwrap().style = style.into();
        self.emit(signal::RedrawNeeded);
        self
    }

    /// Sets a callback to use to generate [`ContentStyle`]s.
    pub fn style_callback<F>(self, callback: F) -> Self
    where
        F: Fn(&str) -> ContentStyle + Send + Sync + 'static,
    {
        self.state.0.lock().unwrap().style = StyleInner::Callback(Box::new(callback));
        self.emit(signal::RedrawNeeded);
        self
    }

    /// Sets a callback to replace the default view function.
    pub fn view_callback<F>(self, callback: F) -> Self
    where
        F: Fn(&str, ContentStyle) -> Option<WidgetDef<Msg>> + Send + Sync + 'static,
    {
        self.state.0.lock().unwrap().view_callback = Some(Box::new(callback));
        self.emit(signal::RedrawNeeded);
        self
    }

    /// Return a copy of the [`TextBox`] current content.
    pub fn get(&self) -> String {
        self.state.0.lock().unwrap().content.clone()
    }

    /// Sets the [`TextBox`] content.
    ///
    /// Calling this function will emit a [`RedrawNeeded`] signal.
    ///
    /// [`RedrawNeeded`]: signal::RedrawNeeded
    pub fn set(&mut self, content: impl Into<String>) {
        self.state.0.lock().unwrap().content = content.into();
        self.emit(signal::RedrawNeeded);
    }

    /// Create a new [`WeakTextBox`].
    pub fn downgrade(&self) -> WeakTextBox<Msg> {
        WeakTextBox(self.state.downgrade())
    }
}

impl<Msg> TextBox<Msg>
where
    Msg: Clone,
{
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

impl<Msg> Default for TextBox<Msg> {
    fn default() -> Self {
        Self::with_content("")
    }
}

impl<Msg> WeakTextBox<Msg> {
    pub fn upgrade(&self) -> Option<TextBox<Msg>> {
        self.0.upgrade().map(|state| TextBox { state })
    }
}

impl<Msg> Widget for Inner<Msg>
where
    Msg: Clone + From<WidgetMessage>,
{
    type Message = Msg;

    fn view(&self) -> Option<snowcap_api::widget::WidgetDef<Self::Message>> {
        let style = self.style.get(&self.content);

        if let Some(callback) = &self.view_callback {
            callback(&self.content, style)
        } else {
            TextBox::default_view(&self.content, style)
        }
    }
}

impl<Msg> WithEmitter for TextBox<Msg> {
    fn with_emitter(&self) -> Emitter {
        self.state.0.lock().unwrap().with_emitter()
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
