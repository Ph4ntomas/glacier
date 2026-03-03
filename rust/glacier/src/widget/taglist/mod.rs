//! TagList widget.
//!
//! [`TagList`] allows to display tags, and control them using the mouse. When the view function is
//! called, this widget first render each [`Tag`], wrapping the result in a [`MouseArea`] which
//! will handle left and right click to switch and toggle the given tag, respectively. This first
//! render pass can be overriden through the use of the [`tag_view_callback`] attribute, and
//! default to calling [`TagList::default_tag_view`].
//!
//! The resulting views are then passed to another function with should render the list itself,
//! whose resulting view will be wrapped in a second `MouseArea`, handing Scroll events. This
//! second render pass can be overriden via the [`list_view_callback`] attribute, and default to
//! calling [`TagList::default_list_view`].
//!
//! [`tag_view_callback`]: TagList::tag_view_callback
//! [`list_view_callback`]: TagList::list_view_callback

use std::time::{Duration, Instant};

use crate::{
    color,
    widget::message::{self, MessageBuilder},
};

use pinnacle_api::{
    output::OutputHandle,
    signal::{SignalHandle, TagSignal},
    tag::TagHandle,
    util::Batch,
};
use snowcap_api::{
    surface::SurfaceEvent,
    widget::{
        self, Program, WidgetDef,
        base::WidgetBase,
        container::Container,
        message::UniversalMsg,
        mouse_area::{self, MouseArea},
        row::Row,
        text::Text,
    },
};

pub mod style;
#[doc(inline)]
pub use style::{Style, TagStyle, brighten_background};

type TagViewCallback<Msg> = Box<dyn Fn(&Tag, TagStyle) -> Option<WidgetDef<Msg>> + Send>;
type ListViewCallback<Msg> =
    Box<dyn Fn(Vec<WidgetDef<Msg>>, Style) -> Option<WidgetDef<Msg>> + Send>;

/// Single Tag state.
pub struct Tag {
    /// Handle to the tag.
    pub handle: TagHandle,
    /// Name of the tag.
    pub name: String,
    /// Whether the tag is currently active.
    pub active: bool,
    /// Whether the tag [`MouseArea`] is hovered.
    pub hovered: bool,
}

impl Tag {
    /// Create a new [`Tag`].
    fn new(handle: TagHandle, name: String, active: bool) -> Self {
        Self {
            handle,
            name,
            active,
            hovered: false,
        }
    }
}

/// [`TagList`] events.
#[derive(Clone, Debug)]
pub enum Event {
    Toggle(TagHandle),
    Switch(TagHandle),
    EnterTag(TagHandle),
    ExitTag(TagHandle),
    NextTag,
    PrevTag,
    SmallScroll,
    ActiveChanged(TagHandle, bool),
}

/// [`TagList`] message type
pub type Message = message::Message<Event>;

pub struct TagList<Msg> {
    base: WidgetBase,
    tags: Vec<Tag>,
    style: Style,
    message_builder: MessageBuilder<Event>,
    tag_view_callback: Option<TagViewCallback<Msg>>,
    list_view_callback: Option<ListViewCallback<Msg>>,
    throttle_scroll: Duration,
    last_scroll: Instant,
    sig_handle: Option<SignalHandle>,
    output: OutputHandle,
}

/// Default [`TagList`] appearance.
pub fn default_style() -> Style {
    use snowcap_api::widget::{
        Border, Padding,
        font::{self, Font},
    };

    Style::new()
        .fg_color(color::from_hex("#CCCCCC"))
        .font(
            Font::new()
                .family(font::Family::Monospace)
                .weight(font::Weight::Bold),
        )
        .border(Border {
            width: Some(0.0),
            ..Default::default()
        })
        .padding(Padding {
            top: 2.,
            bottom: 2.,
            left: 8.,
            right: 8.,
        })
        .spacing(0.)
        .active(TagStyle::new().bg_color(color::from_hex("#33991A")))
        .inactive(TagStyle::new().bg_color(color::from_hex("#666666")))
}

/// Get all [`Tag`]s associated with an output.
pub(crate) fn get_all_tags(output: OutputHandle) -> impl Iterator<Item = Tag> {
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

impl<Msg> TagList<Msg> {
    const PROGRAM_NAME: &'static str = "TAG_LIST";
    const DEFAULT_THROTTLE: Duration = Duration::from_millis(50);

    /// Create a new [`TagList`] for a given [`OutputHandle`].
    pub fn new(output: OutputHandle) -> Self {
        let base = WidgetBase::new(Self::PROGRAM_NAME);
        let message_builder = MessageBuilder::new(base.id());

        Self {
            base,
            tags: Default::default(),
            style: default_style(),
            message_builder,
            tag_view_callback: None,
            list_view_callback: None,
            throttle_scroll: Self::DEFAULT_THROTTLE,
            last_scroll: Instant::now(),
            sig_handle: None,
            output,
        }
    }

    /// Sets the `TagList` [`Style`].
    pub fn style(self, style: Style) -> Self {
        Self { style, ..self }
    }

    /// Sets the callback to render a single [`Tag`].
    pub fn tag_view_callback<F>(self, callback: F) -> Self
    where
        F: Fn(&Tag, TagStyle) -> Option<WidgetDef<Msg>> + Send + 'static,
    {
        Self {
            tag_view_callback: Some(Box::new(callback)),
            ..self
        }
    }

    /// Sets the callback to render the full list.
    pub fn list_view_callback<F>(self, callback: F) -> Self
    where
        F: Fn(Vec<WidgetDef<Msg>>, Style) -> Option<WidgetDef<Msg>> + Send + 'static,
    {
        Self {
            list_view_callback: Some(Box::new(callback)),
            ..self
        }
    }
}

impl<Msg> TagList<Msg> {
    /// Default view to render [`Tag`].
    pub fn default_tag_view(tag: &Tag, style: TagStyle) -> Option<WidgetDef<Msg>> {
        let text = Text::new(tag.name.clone())
            .height(snowcap_api::widget::Length::Fill)
            .width(snowcap_api::widget::Length::Shrink)
            .vertical_alignment(snowcap_api::widget::Alignment::Center)
            .style(style.clone().into());

        let mut widget = Container::new(text).style(style.clone().into());
        widget.padding = style.padding;

        Some(widget.into())
    }

    /// Default view to render a list of [`Tag`].
    pub fn default_list_view(
        children: Vec<WidgetDef<Msg>>,
        style: Style,
    ) -> Option<WidgetDef<Msg>> {
        let mut widget = Row::new_with_children(children)
            .height(snowcap_api::widget::Length::Fill)
            .width(snowcap_api::widget::Length::Shrink);

        widget.spacing = style.spacing;

        Some(widget.into())
    }
}

impl<Msg> TagList<Msg>
where
    Msg: From<UniversalMsg>,
{
    fn view_tags(&self) -> Vec<WidgetDef<Msg>> {
        self.tags
            .iter()
            .filter_map(|t| {
                let style = self.style.get(t.active);
                let style = if t.hovered
                    && let Some(transform) = &self.style.hover_transform
                {
                    transform(style)
                } else {
                    style
                };

                let builder = self.message_builder;

                let tag = if let Some(callback) = self.tag_view_callback.as_ref() {
                    callback(t, style)
                } else {
                    TagList::default_tag_view(t, style)
                };

                tag.map(|c| {
                    MouseArea::new(c)
                        .on_release(builder.switch(t.handle.clone()).into())
                        .on_right_release(builder.toggle(t.handle.clone()).into())
                        .on_enter(builder.enter(t.handle.clone()).into())
                        .on_exit(builder.exit(t.handle.clone()).into())
                        .into()
                })
            })
            .collect()
    }

    fn on_scroll(builder: MessageBuilder<Event>, delta: mouse_area::ScrollDelta) -> Msg {
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

impl<Msg> TagList<Msg> {
    fn set_hover_for(&mut self, handle: TagHandle, hover: bool) {
        for t in self.tags.iter_mut() {
            if t.handle == handle {
                t.hovered = hover;
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
}

impl<Msg> Program for TagList<Msg>
where
    Msg: From<UniversalMsg> + TryInto<UniversalMsg> + Clone + 'static,
{
    type Message = Msg;

    fn view(&self) -> Option<WidgetDef<Self::Message>> {
        if self.tags.is_empty() {
            return None;
        }

        let style = self.style.clone();
        let children = self.view_tags();
        let builder = self.message_builder;

        let list = if let Some(callback) = self.list_view_callback.as_ref() {
            callback(children, style)
        } else {
            TagList::default_list_view(children, style)
        }?;

        let widget = MouseArea::new(list).on_scroll(move |delta| Self::on_scroll(builder, delta));

        Some(widget.into())
    }

    fn event(&mut self, event: snowcap_api::surface::SurfaceEvent<Self::Message>) {
        match event {
            SurfaceEvent::Created { .. } => {
                self.tags = get_all_tags(self.output.clone()).collect();

                let sig_handle = pinnacle_api::tag::connect_signal({
                    let signaler = self.base.signaler();
                    let builder = self.message_builder;
                    TagSignal::Active(Box::new(move |handle, active| {
                        signaler.emit(widget::signal::Message(Msg::from(
                            builder.active_changed(handle.clone(), active),
                        )));
                    }))
                });

                self.sig_handle = Some(sig_handle);
                self.base.signaler().emit(widget::signal::RedrawNeeded);
            }
            SurfaceEvent::Closing => {
                if let Some(handle) = self.sig_handle.take() {
                    handle.disconnect();
                }
            }
            _ => (),
        }
    }

    fn update(&mut self, msg: Self::Message) {
        let Some(universal) = msg.try_into().ok() else {
            return;
        };

        let event = match universal.downcast::<Message>() {
            Ok(message::Message { id, event }) if id == self.base.id() => event,
            _ => return,
        };

        if matches!(event, Event::NextTag | Event::PrevTag) {
            let now = Instant::now();
            let diff = now - self.last_scroll;

            if diff < self.throttle_scroll {
                return;
            } else {
                self.last_scroll = now;
            }
        }

        match event {
            Event::Switch(t) => t.switch_to(),
            Event::Toggle(t) => t.toggle_active(),
            Event::EnterTag(t) => self.set_hover_for(t, true),
            Event::ExitTag(t) => self.set_hover_for(t, false),
            Event::NextTag => self.focus_next_tag(),
            Event::PrevTag => self.focus_prev_tag(),
            Event::ActiveChanged(t, active) => {
                for tag in self.tags.iter_mut() {
                    if tag.handle == t {
                        tag.active = active;
                    }
                }
            }
            _ => {}
        }
    }

    fn signaler(&self) -> Option<snowcap_api::signal::Signaler> {
        Some(self.base.signaler())
    }
}

impl MessageBuilder<Event> {
    fn toggle(&self, handle: TagHandle) -> UniversalMsg {
        self.build(Event::Toggle(handle))
    }

    fn switch(&self, handle: TagHandle) -> UniversalMsg {
        self.build(Event::Switch(handle))
    }

    fn enter(&self, handle: TagHandle) -> UniversalMsg {
        self.build(Event::EnterTag(handle))
    }

    fn exit(&self, handle: TagHandle) -> UniversalMsg {
        self.build(Event::ExitTag(handle))
    }

    fn next_tag(&self) -> UniversalMsg {
        self.build(Event::NextTag)
    }

    fn prev_tag(&self) -> UniversalMsg {
        self.build(Event::PrevTag)
    }

    fn small_scroll(&self) -> UniversalMsg {
        self.build(Event::SmallScroll)
    }

    fn active_changed(&self, handle: TagHandle, active: bool) -> UniversalMsg {
        self.build(Event::ActiveChanged(handle, active))
    }
}
