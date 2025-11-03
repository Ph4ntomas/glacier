use std::marker::PhantomData;

use pinnacle_api::signal::TagSignal;
use pinnacle_api::util::Batch;
use pinnacle_api::{output::OutputHandle, tag::TagHandle};
use snowcap_api::widget::row::Row;
use snowcap_api::widget::text::{self, Text};
use snowcap_api::widget::{self, WidgetDef, container, mouse_area};
use snowcap_api::widget::{container::Container, mouse_area::MouseArea};

use crate::color;
use crate::widget::message::{self, MessageBuilder};
use crate::widget::signal;
use crate::{
    signal::WithEmitter,
    widget::{State, Widget, WidgetMessage, WithState, base::WidgetBase},
};

#[derive(Clone, Debug)]
pub enum Action {
    Toggle(TagHandle),
    Switch(TagHandle),
    EnterTag(TagHandle),
    ExitTag(TagHandle),
    NextTag,
    PrevTag,
    SmallScroll,
}

pub type Message = message::Message<Action>;

struct Tag {
    handle: TagHandle,
    name: String,
    active: bool,
    _hovered: bool,
}

#[derive(Default, Clone)]
pub struct TagStyle {
    pub bg_color: Option<widget::Color>,
    pub fg_color: Option<widget::Color>,
    pub font: Option<widget::font::Font>,
    pub pixels: Option<f32>,
    pub border: Option<widget::Border>,
    pub padding: Option<widget::Padding>,
}

#[derive(Clone)]
pub struct Style {
    pub default: TagStyle,
    pub active: TagStyle,
    pub inactive: TagStyle,
    pub spacing: Option<f32>,
}

pub struct Inner<Msg> {
    base: WidgetBase,
    tags: Vec<Tag>,
    style: Style,
    message_builder: MessageBuilder<Action>,
    _output: OutputHandle,
    _msg: PhantomData<Msg>,
}

#[derive(Clone)]
pub struct TagList<Msg> {
    state: State<Inner<Msg>>,
}

fn default_inner_view<Msg>(tag: &Tag, style: TagStyle) -> WidgetDef<Msg> {
    let text = Text::new(tag.name.clone())
        .height(snowcap_api::widget::Length::Fill)
        .width(snowcap_api::widget::Length::Shrink)
        .vertical_alignment(snowcap_api::widget::Alignment::Center)
        .style(style.clone().into());

    let mut widget = Container::new(text).style(style.clone().into());
    widget.padding = style.padding;

    widget.into()
}

fn default_outer_view<Msg>(children: Vec<WidgetDef<Msg>>, style: &Style) -> WidgetDef<Msg> {
    let mut widget = Row::new_with_children(children)
        .height(snowcap_api::widget::Length::Fill)
        .width(snowcap_api::widget::Length::Shrink);

    widget.spacing = style.spacing;

    widget.into()
}

fn get_all_tags(output: OutputHandle) -> impl Iterator<Item = Tag> {
    output.tags().batch_map(|tag| {
        Box::pin(async {
            Tag::new(
                tag.clone(),
                tag.name_async().await,
                tag.active_async().await,
            )
        })
    })
}

impl<Msg> TagList<Msg>
where
    Msg: Clone + Send + Sync + 'static,
{
    pub fn new(output: OutputHandle) -> Self {
        let tags = get_all_tags(output.clone()).collect();
        let base = WidgetBase::new("TagList");
        let message_builder = MessageBuilder::new(base.id());

        let state = State::new(Inner {
            base,
            tags,
            style: Style::default(),
            message_builder,
            _output: output,
            _msg: PhantomData,
        });

        let weak_state = state.downgrade();

        pinnacle_api::tag::connect_signal(TagSignal::Active(Box::new(move |handle, active| {
            let Some(state) = weak_state.upgrade() else {
                return;
            };

            let mut inner = state.0.lock().unwrap();

            for tag in inner.tags.iter_mut() {
                if &tag.handle == handle {
                    tag.active = active;
                    inner.emit(signal::RedrawNeeded);
                    return;
                }
            }
        })));

        Self { state }
    }
}

impl<Msg> WithState for TagList<Msg> {
    type Type = Inner<Msg>;

    fn with_state(&self) -> State<Self::Type> {
        self.state.clone()
    }
}

impl<Msg> Inner<Msg>
where
    Msg: From<WidgetMessage>,
{
    fn view_tags(&self) -> Vec<WidgetDef<Msg>> {
        self.tags
            .iter()
            .map(|t| {
                let style = if t.active {
                    self.style.active.clone()
                } else {
                    self.style.inactive.clone()
                };

                let builder = self.message_builder;

                MouseArea::new(default_inner_view(t, style))
                    .on_release(builder.switch(t.handle.clone()).into())
                    .on_right_release(builder.toggle(t.handle.clone()).into())
                    .on_enter(builder.enter(t.handle.clone()).into())
                    .on_exit(builder.exit(t.handle.clone()).into())
                    .into()
            })
            .collect()
    }

    fn set_hover_for(&mut self, handle: TagHandle, hover: bool) {
        for t in self.tags.iter_mut() {
            if t.handle == handle {
                t._hovered = hover;
                return;
            }
        }
    }

    fn find_active_idx(&self) -> Option<usize> {
        self.tags
            .iter()
            .enumerate()
            .find(|(_, t)| t.active)
            .map(|(idx, _)| idx)
    }

    fn focus_next_tag(&mut self) {
        if let Some(idx) = self.find_active_idx() {
            let idx = (idx + 1) % self.tags.len();

            self.tags[idx].handle.switch_to();
        } else if let Some(t) = self.tags.first_mut() {
            t.handle.switch_to();
        }
    }

    fn focus_prev_tag(&mut self) {
        if let Some(idx) = self.find_active_idx() {
            let idx = if idx == 0 { self.tags.len() } else { idx };
            let idx = idx - 1;

            self.tags[idx].handle.switch_to();
        } else if let Some(t) = self.tags.last_mut() {
            t.handle.switch_to();
        }
    }

    fn on_scroll(builder: MessageBuilder<Action>, delta: mouse_area::ScrollDelta) -> Msg {
        let delta = match delta {
            mouse_area::ScrollDelta::Lines { x, y } => {
                if f32::abs(x) > f32::abs(y) {
                    x
                } else {
                    y
                }
            }
            mouse_area::ScrollDelta::Pixels { x, y } => {
                if f32::abs(x) > f32::abs(y) {
                    x
                } else {
                    y
                }
            }
        };

        if delta > 0.5 {
            builder.next_tag().into()
        } else if delta < -0.5 {
            builder.prev_tag().into()
        } else {
            builder.small_scroll().into()
        }
    }
}

impl<Msg> WithEmitter for Inner<Msg> {
    fn with_emitter(&self) -> crate::signal::Emitter {
        self.base.with_emitter()
    }
}

impl<Msg> Widget for Inner<Msg>
where
    Msg: Clone + From<WidgetMessage> + Into<Option<WidgetMessage>> + Send + Sync,
{
    type Message = Msg;

    fn view(&self) -> Option<snowcap_api::widget::WidgetDef<Self::Message>> {
        if self.tags.is_empty() {
            return None;
        };

        let children = self.view_tags();

        let builder = self.message_builder;
        let widget = MouseArea::new(default_outer_view(children, &self.style))
            .on_scroll(move |delta| Self::on_scroll(builder, delta));

        Some(widget.into())
    }

    fn update(&mut self, msg: Self::Message) {
        let Some(msg) = msg.into() else {
            return;
        };

        let action = match msg {
            WidgetMessage::TagList(Message { id, action }) if id == self.base.id() => action,
            _ => return,
        };

        match action {
            Action::Switch(t) => t.switch_to(),
            Action::Toggle(t) => t.toggle_active(),
            Action::EnterTag(t) => self.set_hover_for(t, true),
            Action::ExitTag(t) => self.set_hover_for(t, false),
            Action::NextTag => self.focus_next_tag(),
            Action::PrevTag => self.focus_prev_tag(),
            _ => {}
        }
    }
}

impl Tag {
    fn new(handle: TagHandle, name: String, active: bool) -> Self {
        Self {
            handle,
            name,
            active,
            _hovered: false,
        }
    }
}

impl TagStyle {
    pub fn new() -> Self {
        Self::default()
    }

    fn merge_with(&self, other: TagStyle) -> TagStyle {
        let TagStyle {
            bg_color,
            fg_color,
            font,
            pixels,
            border,
            padding,
        } = other;

        let bg_color = bg_color.or(self.bg_color);
        let fg_color = fg_color.or(self.fg_color);
        let font = font.or_else(|| self.font.clone());
        let pixels = pixels.or(self.pixels);
        let border = border.or(self.border);
        let padding = padding.or(self.padding);

        TagStyle {
            bg_color,
            fg_color,
            font,
            pixels,
            border,
            padding,
        }
    }

    pub fn with_bg_color(self, bg_color: widget::Color) -> Self {
        Self {
            bg_color: Some(bg_color),
            ..self
        }
    }

    pub fn with_fg_color(self, fg_color: widget::Color) -> Self {
        Self {
            fg_color: Some(fg_color),
            ..self
        }
    }

    pub fn with_font(self, font: widget::font::Font) -> Self {
        Self {
            font: Some(font),
            ..self
        }
    }

    pub fn with_border(self, border: widget::Border) -> Self {
        Self {
            border: Some(border),
            ..self
        }
    }

    pub fn with_padding(self, padding: widget::Padding) -> Self {
        Self {
            padding: Some(padding),
            ..self
        }
    }
}

impl From<TagStyle> for container::Style {
    fn from(value: TagStyle) -> Self {
        Self {
            text_color: value.fg_color,
            background_color: value.bg_color,
            border: value.border,
        }
    }
}

impl From<TagStyle> for text::Style {
    fn from(value: TagStyle) -> Self {
        let TagStyle {
            fg_color: color,
            font,
            pixels,
            ..
        } = value;
        Self {
            color,
            pixels,
            font,
        }
    }
}

impl Style {
    fn new_from_part(
        default: TagStyle,
        active: TagStyle,
        inactive: TagStyle,
        spacing: Option<f32>,
    ) -> Self {
        let active = default.merge_with(active);
        let inactive = default.merge_with(inactive);

        Self {
            default,
            active,
            inactive,
            spacing,
        }
    }
}

impl Default for Style {
    fn default() -> Self {
        let default_font = widget::font::Font::new()
            .family(widget::font::Family::Monospace)
            .weight(widget::font::Weight::Bold);

        let default = TagStyle::new()
            .with_fg_color(color::from_hex("#CCCCCC"))
            .with_font(default_font)
            .with_padding(widget::Padding {
                top: 2.,
                right: 8.,
                bottom: 2.,
                left: 8.,
            });

        let active = TagStyle::new().with_bg_color(color::from_hex("#33991A"));

        let inactive = TagStyle::new().with_bg_color(color::from_hex("#666666"));

        Self::new_from_part(default, active, inactive, None)
    }
}

impl From<Message> for WidgetMessage {
    fn from(value: Message) -> Self {
        Self::TagList(value)
    }
}

impl MessageBuilder<Action> {
    fn toggle(&self, handle: TagHandle) -> WidgetMessage {
        self.build(Action::Toggle(handle))
    }

    fn switch(&self, handle: TagHandle) -> WidgetMessage {
        self.build(Action::Switch(handle))
    }

    fn enter(&self, handle: TagHandle) -> WidgetMessage {
        self.build(Action::EnterTag(handle))
    }

    fn exit(&self, handle: TagHandle) -> WidgetMessage {
        self.build(Action::ExitTag(handle))
    }

    fn next_tag(&self) -> WidgetMessage {
        self.build(Action::NextTag)
    }

    fn prev_tag(&self) -> WidgetMessage {
        self.build(Action::PrevTag)
    }

    fn small_scroll(&self) -> WidgetMessage {
        self.build(Action::SmallScroll)
    }
}
