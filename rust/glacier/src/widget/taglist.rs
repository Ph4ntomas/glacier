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

use pinnacle_api::signal::TagSignal;
use pinnacle_api::util::Batch;
use pinnacle_api::{output::OutputHandle, tag::TagHandle};
use snowcap_api::widget::row::Row;
use snowcap_api::widget::text::Text;
use snowcap_api::widget::{WidgetDef, mouse_area};
use snowcap_api::widget::{container::Container, mouse_area::MouseArea};

use crate::color;
use crate::widget::message::{self, MessageBuilder};
use crate::widget::{WeakState, signal};
use crate::{
    signal::WithEmitter,
    widget::{State, Widget, WidgetMessage, WithState, base::WidgetBase},
};

pub mod style;
#[doc(inline)]
pub use style::{Style, TagStyle, brighten_background};

type TagViewCallback<Msg> = Box<dyn Fn(&Tag, TagStyle) -> Option<WidgetDef<Msg>> + Send + Sync>;
type ListViewCallback<Msg> =
    Box<dyn Fn(Vec<WidgetDef<Msg>>, Style) -> Option<WidgetDef<Msg>> + Send + Sync>;

/// [`TagList`] actions.
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

/// [`TagList`] messages type.
pub type Message = message::Message<Action>;

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

/// Internal [`TagList`] stste.
pub struct Inner<Msg> {
    base: WidgetBase,
    tags: Vec<Tag>,
    style: Style,
    message_builder: MessageBuilder<Action>,
    tag_view_callback: Option<TagViewCallback<Msg>>,
    list_view_callback: Option<ListViewCallback<Msg>>,
    throttle_scroll: Duration,
    last_scroll: Instant,
    _output: OutputHandle,
}

/// Widget representing a list of Tags.
#[derive(Clone)]
pub struct TagList<Msg> {
    state: State<Inner<Msg>>,
}

/// Non-owning version of the [`TagList`].
#[derive(Clone)]
pub struct WeakTagList<Msg>(WeakState<Inner<Msg>>);

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
    Msg: Send + 'static,
{
    const DEFAULT_THROTTLE: Duration = Duration::from_millis(50);

    /// Create a new [`TagList`] for a given [`OutputHandle`].
    pub fn new(output: OutputHandle) -> Self {
        let tags = get_all_tags(output.clone()).collect();
        let base = WidgetBase::new("TagList");
        let message_builder = MessageBuilder::new(base.id());

        let state = State::new(Inner {
            base,
            tags,
            style: default_style(),
            message_builder,
            tag_view_callback: None,
            list_view_callback: None,
            throttle_scroll: Self::DEFAULT_THROTTLE,
            last_scroll: Instant::now(),
            _output: output,
        });

        let list = Self { state };
        let weak = list.downgrade();

        pinnacle_api::tag::connect_signal(TagSignal::Active(Box::new(move |handle, active| {
            let Some(list) = weak.upgrade() else {
                return;
            };

            let mut redraw = false;

            {
                let mut inner = list.state.0.lock().unwrap();

                for tag in inner.tags.iter_mut() {
                    if &tag.handle == handle {
                        tag.active = active;
                        redraw = true;
                        break;
                    }
                }
            }

            if redraw {
                list.emit(signal::RedrawNeeded);
            }
        })));

        list
    }

    /// Sets the [`Style`].
    pub fn style(self, style: Style) -> Self {
        self.state.0.lock().unwrap().style = style;
        self.emit(signal::RedrawNeeded);
        self
    }

    /// Sets the callback to render a single [`Tag`].
    pub fn tag_view_callback<F>(self, callback: F) -> Self
    where
        F: Fn(&Tag, TagStyle) -> Option<WidgetDef<Msg>> + Send + Sync + 'static,
    {
        self.state.0.lock().unwrap().tag_view_callback = Some(Box::new(callback));
        self.emit(signal::RedrawNeeded);
        self
    }

    /// Sets the callback to render the full list.
    pub fn list_view_callback<F>(self, callback: F) -> Self
    where
        F: Fn(Vec<WidgetDef<Msg>>, Style) -> Option<WidgetDef<Msg>> + Send + Sync + 'static,
    {
        self.state.0.lock().unwrap().list_view_callback = Some(Box::new(callback));
        self.emit(signal::RedrawNeeded);
        self
    }

    /// Sets the cooldown time between two Scroll events.
    pub fn throttle_scroll(self, throttle: Duration) -> Self {
        self.state.0.lock().unwrap().throttle_scroll = throttle;
        self
    }

    /// Create a new [`WeakTagList`] for this `TagList`.
    pub fn downgrade(&self) -> WeakTagList<Msg> {
        WeakTagList(self.state.downgrade())
    }

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

impl<Msg> WeakTagList<Msg> {
    /// Attempts to upgrade this `WeakTagList` to a [`TagList`].
    ///
    /// Returns [`None`] if the [`TagList`] has already been dropped.
    pub fn upgrade(&self) -> Option<TagList<Msg>> {
        self.0.upgrade().map(|state| TagList { state })
    }
}

impl<Msg> Inner<Msg>
where
    Msg: From<WidgetMessage> + Send + 'static,
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

                let tag = if let Some(callback) = &self.tag_view_callback {
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

impl<Msg> WithEmitter for TagList<Msg> {
    fn with_emitter(&self) -> crate::signal::Emitter {
        self.state.0.lock().unwrap().with_emitter()
    }
}

impl<Msg> WithState for TagList<Msg> {
    type Type = Inner<Msg>;

    fn with_state(&self) -> State<Self::Type> {
        self.state.clone()
    }
}

impl<Msg> WithEmitter for Inner<Msg> {
    fn with_emitter(&self) -> crate::signal::Emitter {
        self.base.with_emitter()
    }
}

impl<Msg> Widget for Inner<Msg>
where
    Msg: Clone + From<WidgetMessage> + Into<Option<WidgetMessage>> + Send + Sync + 'static,
{
    type Message = Msg;

    fn view(&self) -> Option<snowcap_api::widget::WidgetDef<Self::Message>> {
        if self.tags.is_empty() {
            return None;
        };

        let style = self.style.clone();
        let children = self.view_tags();
        let builder = self.message_builder;

        let list = if let Some(callback) = &self.list_view_callback {
            callback(children, style)
        } else {
            TagList::default_list_view(children, style)
        }?;

        let widget = MouseArea::new(list).on_scroll(move |delta| Self::on_scroll(builder, delta));

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

        if matches!(action, Action::NextTag | Action::PrevTag) {
            let now = Instant::now();
            let diff = now - self.last_scroll;

            if diff < self.throttle_scroll {
                return;
            } else {
                self.last_scroll = now;
            }
        }

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
            hovered: false,
        }
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
