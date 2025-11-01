use std::{
    fmt::Debug,
    num::NonZero,
    sync::{Arc, Mutex, Weak},
};

use pinnacle_api::output::OutputHandle;

use snowcap_api::{
    input::KeyEvent,
    layer::LayerHandle,
    widget::{self, Border, Color, Padding, WidgetDef},
};

use crate::{
    signal::TryWithEmitter,
    widget::{WidgetMessage, signal},
};

mod child;
use child::Child;
pub use child::children;

#[derive(Clone)]
pub enum BarMessage<Msg> {
    Empty,
    BuiltinWidget(WidgetMessage),
    Custom(Msg),
}

impl<Msg> From<WidgetMessage> for BarMessage<Msg> {
    fn from(value: WidgetMessage) -> Self {
        Self::BuiltinWidget(value)
    }
}

impl<Msg> Debug for BarMessage<Msg>
where
    Msg: Debug,
{
    fn fmt(&self, _f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        todo!()
    }
}

#[derive(Default, Debug, Clone)]
pub struct Style {
    /// Dimension of the bar, in pixel.
    dimension: f32,
    padding: Option<widget::Padding>,
    background_color: Option<widget::Color>,
    border: Option<widget::Border>,
    spacing: Option<f32>,
}

impl From<Style> for snowcap_api::widget::container::Style {
    fn from(value: Style) -> Self {
        let Style {
            background_color,
            border,
            ..
        } = value;
        Self {
            text_color: None,
            background_color,
            border,
        }
    }
}

pub struct BarProgram<Msg> {
    style: Style,
    first: Weak<Mutex<Vec<Child<Msg>>>>,
    center: Weak<Mutex<Vec<Child<Msg>>>>,
    last: Weak<Mutex<Vec<Child<Msg>>>>,
}

impl<Msg> BarProgram<Msg>
where
    Msg: Clone,
{
    fn view_children(children: Arc<Mutex<Vec<Child<Msg>>>>) -> Vec<WidgetDef<BarMessage<Msg>>> {
        let children = children.try_lock().expect("Failed to lock children");
        children.iter().filter_map(Child::view).collect()
    }

    fn update_children(children: Arc<Mutex<Vec<Child<Msg>>>>, msg: BarMessage<Msg>) {
        let mut children = children.try_lock().expect("Failed to lock children");
        (*children)
            .iter_mut()
            .for_each(move |c| c.update(msg.clone()))
    }

    fn render_first(
        children: Vec<WidgetDef<BarMessage<Msg>>>,
        style: &Style,
    ) -> WidgetDef<BarMessage<Msg>> {
        use widget::row::Row;
        let mut children = Row::new_with_children(children)
            .item_alignment(widget::Alignment::Start)
            .height(widget::Length::Fill)
            .width(widget::Length::Shrink);

        if let Some(spacing) = style.spacing {
            children = children.spacing(spacing);
        }

        children.into()
    }

    fn render_center(
        children: Vec<WidgetDef<BarMessage<Msg>>>,
        style: &Style,
    ) -> WidgetDef<BarMessage<Msg>> {
        use widget::row::Row;
        let mut children = Row::new_with_children(children)
            .item_alignment(widget::Alignment::Start)
            .height(widget::Length::Fill)
            .width(widget::Length::Fill);

        if let Some(spacing) = style.spacing {
            children = children.spacing(spacing);
        }

        children.into()
    }

    fn render_last(
        children: Vec<WidgetDef<BarMessage<Msg>>>,
        style: &Style,
    ) -> WidgetDef<BarMessage<Msg>> {
        use widget::row::Row;
        let mut children = Row::new_with_children(children)
            .item_alignment(widget::Alignment::End)
            .height(widget::Length::Fill)
            .width(widget::Length::Shrink);

        if let Some(spacing) = style.spacing {
            children = children.spacing(spacing);
        }

        children.into()
    }
}

impl<Msg> widget::Program for BarProgram<Msg>
where
    Msg: Clone,
{
    type Message = BarMessage<Msg>;

    fn view(&self) -> widget::WidgetDef<Self::Message> {
        use widget::container::Container;
        use widget::row::Row;

        let first_children = self
            .first
            .upgrade()
            .map(Self::view_children)
            .unwrap_or_default();

        let center_children = self
            .center
            .upgrade()
            .map(Self::view_children)
            .unwrap_or_default();

        let last_children = self
            .last
            .upgrade()
            .map(Self::view_children)
            .unwrap_or_default();

        let mut children = Row::new()
            .item_alignment(widget::Alignment::Start)
            .height(widget::Length::Fixed(self.style.dimension))
            .push(Self::render_first(first_children, &self.style))
            .push(Self::render_center(center_children, &self.style))
            .push(Self::render_last(last_children, &self.style));

        if let Some(spacing) = self.style.spacing {
            children = children.spacing(spacing);
        }

        let mut container = Container::new(children)
            .width(widget::Length::Fill)
            .vertical_alignment(widget::Alignment::Start)
            .horizontal_alignment(widget::Alignment::Start)
            .style(self.style.clone().into());

        if let Some(padding) = self.style.padding {
            container = container.padding(padding);
        }

        container.into()
    }

    fn update(&mut self, msg: Self::Message) {
        match msg {
            Self::Message::Empty => {}
            _ => {
                if let Some(children) = self.first.upgrade() {
                    Self::update_children(children, msg.clone());
                }
            }
        }
    }
}

struct BarHandle<Msg>(Arc<Mutex<Option<snowcap_api::layer::LayerHandle<BarMessage<Msg>>>>>);

struct WeakBarHandle<Msg>(Weak<Mutex<Option<snowcap_api::layer::LayerHandle<BarMessage<Msg>>>>>);

impl<Msg> BarHandle<Msg>
where
    Msg: Send + Clone + 'static,
{
    pub fn set(&mut self, handle: LayerHandle<BarMessage<Msg>>) {
        let mut inner = self.0.try_lock().unwrap();

        *inner = Some(handle)
    }

    pub fn downgrade(handle: &Self) -> WeakBarHandle<Msg> {
        WeakBarHandle(Arc::downgrade(&handle.0))
    }

    pub fn on_key_event<F>(&mut self, on_event: F)
    where
        F: FnMut(LayerHandle<BarMessage<Msg>>, KeyEvent) + Send + 'static,
    {
        let inner = self.0.try_lock().unwrap();

        if let Some(handle) = &*inner {
            handle.on_key_event(on_event);
        }
    }

    pub fn send_message(&self, msg: BarMessage<Msg>) {
        let inner = self.0.try_lock().unwrap();

        if let Some(handle) = &*inner {
            handle.send_message(msg);
        }
    }
}

impl<Msg> Default for BarHandle<Msg> {
    fn default() -> Self {
        Self(Arc::default())
    }
}

impl<Msg> WeakBarHandle<Msg> {
    pub fn upgrade(&self) -> Option<BarHandle<Msg>> {
        self.0.upgrade().map(|arc| BarHandle(arc))
    }
}

pub struct Bar<Msg> {
    handle: BarHandle<Msg>,
    style: Style,
    first: Arc<Mutex<Vec<Child<Msg>>>>,
    center: Arc<Mutex<Vec<Child<Msg>>>>,
    last: Arc<Mutex<Vec<Child<Msg>>>>,
}

impl<Msg> Bar<Msg>
where
    Msg: Clone + Send + 'static,
{
    fn process_children(handle: &BarHandle<Msg>, children: &mut Vec<Child<Msg>>) {
        for c in children {
            let weak_handle = BarHandle::downgrade(handle);

            if let Some(mut emitter) = c.try_with_emitter() {
                emitter.connect(move |_: signal::RedrawNeeded| {
                    let Some(handle) = weak_handle.upgrade() else {
                        return false;
                    };

                    handle.send_message(BarMessage::Empty);

                    false
                });
            }
        }
    }

    pub fn new(
        output: Option<OutputHandle>,
        style: Style,
        mut first: Vec<Child<Msg>>,
        mut center: Vec<Child<Msg>>,
        mut last: Vec<Child<Msg>>,
    ) -> Self {
        let mut restore_output = None;

        let focused_output = pinnacle_api::output::get_focused();

        if output.is_some() {
            restore_output = focused_output.clone();
        }

        let output = output.or(focused_output).expect("Bar needs an output");
        output.focus();

        let handle = BarHandle::default();

        Self::process_children(&handle, &mut first);
        Self::process_children(&handle, &mut center);
        Self::process_children(&handle, &mut last);

        let mut bar = Self {
            handle,
            style,
            first: Arc::new(Mutex::new(first)),
            center: Arc::new(Mutex::new(center)),
            last: Arc::new(Mutex::new(last)),
        };

        bar.show();

        if let Some(output) = restore_output {
            output.focus();
        }

        bar
    }

    pub fn show(&mut self) {
        use snowcap_api::layer;

        let total_dimension = (self.style.dimension
            + self.style.padding.map(|p| p.top + p.bottom).unwrap_or(0.0))
        .ceil();
        let mut exclusive_dimension: u32 = total_dimension as u32;

        if exclusive_dimension == 0 {
            exclusive_dimension = 1;
        }

        let program = BarProgram::<Msg> {
            style: self.style.clone(),
            first: Arc::downgrade(&self.first),
            center: Arc::downgrade(&self.center),
            last: Arc::downgrade(&self.last),
        };

        self.handle.set(
            layer::new_widget(
                program,
                Some(layer::Anchor::Top),
                layer::KeyboardInteractivity::None,
                layer::ExclusiveZone::Exclusive(NonZero::new(exclusive_dimension).unwrap()),
                layer::ZLayer::Top,
            )
            .expect("Could not create Layer for bar"),
        );

        self.handle.on_key_event(|_, _| {});
    }
}

pub struct BarBuilder<Msg> {
    style: Style,
    output: Option<pinnacle_api::output::OutputHandle>,
    first: Vec<Child<Msg>>,
    center: Vec<Child<Msg>>,
    last: Vec<Child<Msg>>,
}

impl<Msg> BarBuilder<Msg>
where
    Msg: Clone + Send + 'static,
{
    pub fn new() -> BarBuilder<Msg> {
        Self {
            style: Style {
                dimension: 24.,
                padding: Some(Padding {
                    top: 8.,
                    right: 8.,
                    bottom: 8.,
                    left: 8.,
                }),
                background_color: Some(Color::rgba(0.15, 0.03, 0.1, 0.65)),
                border: Some(Border {
                    width: Some(0.0),
                    ..Default::default()
                }),
                spacing: None,
            },
            output: None,
            first: Vec::default(),
            center: Vec::default(),
            last: Vec::default(),
        }
    }

    pub fn with_output(&mut self, output: pinnacle_api::output::OutputHandle) -> &mut Self {
        self.output = Some(output);

        self
    }

    pub fn with_style(&mut self, style: Style) -> &mut Self {
        self.style = style;

        self
    }

    pub fn with_dimension(&mut self, dimension: f32) -> &mut Self {
        self.style.dimension = dimension;

        self
    }

    pub fn with_padding(&mut self, padding: Padding) -> &mut Self {
        self.style.padding = Some(padding);

        self
    }

    pub fn with_background_color(&mut self, color: Color) -> &mut Self {
        self.style.background_color = Some(color);

        self
    }

    pub fn with_border(&mut self, border: Border) -> &mut Self {
        self.style.border = Some(border);

        self
    }

    pub fn with_spacing(&mut self, spacing: f32) -> &mut Self {
        self.style.spacing = Some(spacing);

        self
    }

    pub fn with_first(&mut self, children: Vec<Child<Msg>>) -> &mut Self {
        self.first = children;

        self
    }

    pub fn with_center(&mut self, children: Vec<Child<Msg>>) -> &mut Self {
        self.center = children;

        self
    }

    pub fn with_last(&mut self, children: Vec<Child<Msg>>) -> &mut Self {
        self.last = children;

        self
    }

    pub fn build(&mut self) -> Bar<Msg> {
        let first = std::mem::take(&mut self.first);
        let center = std::mem::take(&mut self.center);
        let last = std::mem::take(&mut self.last);

        Bar::new(self.output.clone(), self.style.clone(), first, center, last)
    }
}

impl<Msg> Default for BarBuilder<Msg>
where
    Msg: Clone + Send + 'static,
{
    fn default() -> Self {
        Self::new()
    }
}

pub fn builder<Msg>() -> BarBuilder<Msg>
where
    Msg: Clone + Send + 'static,
{
    BarBuilder::new()
}
