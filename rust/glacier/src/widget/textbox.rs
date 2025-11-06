use snowcap_api::widget::{Alignment, Length, WidgetDef, container::Container, text::Text};

use crate::{
    signal::{Emitter, WithEmitter},
    widget::{State, WeakState, Widget, WidgetMessage, WithState, base::WidgetBase, signal},
};

pub mod style;

pub use style::{ContentStyle, Style, StyleLookup};

type ViewCallback<Msg> =
    Box<dyn Fn(&str, ContentStyle) -> Option<WidgetDef<Msg>> + Send + Sync + 'static>;

pub struct Inner<Msg> {
    base: WidgetBase,
    content: String,
    styles: Style,
    view_callback: Option<ViewCallback<Msg>>,
}

#[derive(Clone)]
pub struct TextBox<Msg> {
    state: State<Inner<Msg>>,
}

#[derive(Clone)]
pub struct WeakTextBox<Msg>(WeakState<Inner<Msg>>);

pub fn default_style() -> StyleLookup {
    StyleLookup::default()
}

impl<Msg> TextBox<Msg> {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn with_content(content: impl Into<String>) -> Self {
        let state = State::new(Inner {
            base: WidgetBase::new("TextBox"),
            content: content.into(),
            styles: default_style().into(),
            view_callback: None,
        });

        Self { state }
    }

    pub fn style(self, styles: impl Into<Style>) -> Self {
        self.state.0.lock().unwrap().styles = styles.into();
        self.emit(signal::RedrawNeeded);
        self
    }

    pub fn view_callback<F>(self, callback: F) -> Self
    where
        F: Fn(&str, ContentStyle) -> Option<WidgetDef<Msg>> + Send + Sync + 'static,
    {
        self.state.0.lock().unwrap().view_callback = Some(Box::new(callback));
        self.emit(signal::RedrawNeeded);
        self
    }

    pub fn get(&self) -> String {
        self.state.0.lock().unwrap().content.clone()
    }

    pub fn set(&mut self, content: impl Into<String>) {
        self.state.0.lock().unwrap().content = content.into();
        self.emit(signal::RedrawNeeded);
    }

    pub fn downgrade(&self) -> WeakTextBox<Msg> {
        WeakTextBox(self.state.downgrade())
    }
}

impl<Msg> TextBox<Msg>
where
    Msg: Clone,
{
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
        let style = self.styles.get(&self.content);

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
