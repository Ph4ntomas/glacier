use std::{
    num::NonZero,
    sync::{Arc, Mutex, Weak},
};

use pinnacle_api::output::OutputHandle;
use snowcap_api::{
    layer::{self, KeyboardInteractivity, LayerHandle},
    widget::{self, Padding, Program, WidgetDef, container::Container, row::Row},
};

use crate::{
    color,
    signal::{HandlerPolicy, TryWithEmitter},
    widget::{WidgetMessage, operation, signal},
};

pub mod style;
pub use style::Style;

mod child;
use child::Child;
pub use child::children;

#[derive(Clone)]
pub enum BarMessage<Msg> {
    Empty,
    Operation(operation::Operation),
    BuiltinWidget(WidgetMessage),
    Custom(Msg),
}

type BarWidgetDef<Msg> = WidgetDef<BarMessage<Msg>>;
type ViewCallback<Msg> =
    Box<dyn Fn(Vec<BarWidgetDef<Msg>>, &Style) -> BarWidgetDef<Msg> + Send + Sync>;

pub struct Inner<Msg> {
    style: Style,
    first: Arc<Mutex<Vec<Child<Msg>>>>,
    center: Arc<Mutex<Vec<Child<Msg>>>>,
    last: Arc<Mutex<Vec<Child<Msg>>>>,

    first_view: Option<ViewCallback<Msg>>,
    center_view: Option<ViewCallback<Msg>>,
    last_view: Option<ViewCallback<Msg>>,
    handle: Option<LayerHandle<BarMessage<Msg>>>,
}

pub struct BarProgram<Msg>(WeakBar<Msg>);

pub struct Bar<Msg> {
    state: Arc<Mutex<Inner<Msg>>>,
}

#[derive(Clone)]
pub struct WeakBar<Msg>(Weak<Mutex<Inner<Msg>>>);

pub fn default_style() -> Style {
    Style::new()
        .pixels(24.)
        .padding(Padding::from(8.))
        .bg_color(color::from_hex("#1a1a1a"))
}

impl<Msg> Bar<Msg>
where
    Msg: Clone + Send + 'static,
{
    pub fn new() -> Self {
        let inner = Inner {
            style: default_style(),
            first: Default::default(),
            center: Default::default(),
            last: Default::default(),
            first_view: None,
            center_view: None,
            last_view: None,
            handle: None,
        };

        Self {
            state: Arc::new(Mutex::new(inner)),
        }
    }

    pub fn style(self, style: Style) -> Self {
        self.state.lock().unwrap().style = style;
        if let Some(handle) = self.get_layer() {
            handle.send_message(BarMessage::Empty);
        }
        self
    }

    pub fn first(self, children: Vec<Child<Msg>>) -> Self {
        let children = self.process_children(children);
        *self.state.lock().unwrap().first.lock().unwrap() = children;
        self
    }

    pub fn center(self, children: Vec<Child<Msg>>) -> Self {
        let children = self.process_children(children);
        *self.state.lock().unwrap().center.lock().unwrap() = children;
        self
    }

    pub fn last(self, children: Vec<Child<Msg>>) -> Self {
        let children = self.process_children(children);
        *self.state.lock().unwrap().last.lock().unwrap() = children;
        self
    }

    pub fn show(self, output: Option<OutputHandle>) -> Self {
        let mut restore_output = None;
        let focused_output = pinnacle_api::output::get_focused();

        if output.is_some() {
            restore_output = focused_output.clone();
        }

        let output = output.or(focused_output).expect("Bar needs an output.");
        output.focus();

        let exclusive = self.get_exclusive_size();
        let program = BarProgram(self.downgrade());

        let handle = layer::new_widget(
            program,
            Some(layer::Anchor::Top),
            layer::KeyboardInteractivity::None,
            layer::ExclusiveZone::Exclusive(exclusive),
            layer::ZLayer::Top,
        )
        .expect("Could not create Layer for this bar.");

        handle.on_key_event(|handle, event| {
            use xkbcommon::xkb::Keysym;

            if event.pressed && event.key == Keysym::Escape {
                handle.send_message(BarMessage::Operation(operation::Focusable::Unfocus.into()));
            }
        });

        self.state.lock().unwrap().handle = Some(handle);

        if let Some(output) = restore_output {
            output.focus();
        }

        self
    }

    pub fn close(self) {
        if let Some(handle) = self.state.lock().unwrap().handle.take() {
            handle.close();
        }
    }

    pub fn downgrade(&self) -> WeakBar<Msg> {
        WeakBar(Arc::downgrade(&self.state))
    }

    pub fn focus(&self) {
        if let Some(handle) = self.get_layer() {
            let _ = handle
                .set_keyboard_interactivity(snowcap_api::layer::KeyboardInteractivity::Exclusive);
        }
    }

    pub fn unfocus(&self) {
        if let Some(handle) = self.get_layer() {
            let _ =
                handle.set_keyboard_interactivity(snowcap_api::layer::KeyboardInteractivity::None);
        }
    }

    fn get_exclusive_size(&self) -> NonZero<u32> {
        let state = self.state.lock().unwrap();

        let sum_dimension =
            state.style.pixels + state.style.padding.map(|p| p.top + p.bottom).unwrap_or(0.0);
        let exclusive = u32::max(1, sum_dimension as u32);

        NonZero::new(exclusive).unwrap()
    }

    fn get_layer(&self) -> Option<LayerHandle<BarMessage<Msg>>> {
        self.state.lock().unwrap().handle.clone()
    }

    fn process_child(&self, child: Child<Msg>) -> Child<Msg> {
        if let Some(mut emitter) = child.try_with_emitter() {
            emitter.connect({
                let weak = self.downgrade();
                move |_: signal::RedrawNeeded| {
                    let Some(bar) = weak.upgrade() else {
                        return HandlerPolicy::Discard;
                    };

                    if let Some(handle) = bar.get_layer() {
                        handle.send_message(BarMessage::Empty);
                    }

                    HandlerPolicy::Keep
                }
            });

            emitter.connect({
                let weak = self.downgrade();
                move |_: signal::RequestUnfocus| {
                    let Some(bar) = weak.upgrade() else {
                        return HandlerPolicy::Discard;
                    };

                    if let Some(handle) = bar.get_layer() {
                        handle.send_message(BarMessage::Operation(
                            operation::Focusable::Unfocus.into(),
                        ));
                    }

                    HandlerPolicy::Keep
                }
            });

            emitter.connect({
                let weak = self.downgrade();
                move |signal::RequestFocus(id)| {
                    let Some(bar) = weak.upgrade() else {
                        return HandlerPolicy::Discard;
                    };

                    if let Some(handle) = bar.get_layer() {
                        handle.send_message(BarMessage::Operation(
                            operation::Focusable::Focus(id).into(),
                        ));
                    }

                    HandlerPolicy::Keep
                }
            });
        }
        child
    }

    fn process_children(&self, children: Vec<Child<Msg>>) -> Vec<Child<Msg>> {
        children
            .into_iter()
            .map(|c| self.process_child(c))
            .collect()
    }

    pub fn default_first_view(
        children: Vec<BarWidgetDef<Msg>>,
        style: &Style,
    ) -> BarWidgetDef<Msg> {
        let spacing = style.get_first_spacing();
        let mut row = Row::new_with_children(children)
            .height(widget::Length::Fill)
            .item_alignment(widget::Alignment::Start)
            .width(widget::Length::Shrink);
        row.spacing = spacing;

        row.into()
    }

    pub fn default_center_view(
        children: Vec<BarWidgetDef<Msg>>,
        style: &Style,
    ) -> BarWidgetDef<Msg> {
        let spacing = style.get_center_spacing();
        let mut row = Row::new_with_children(children)
            .height(widget::Length::Fill)
            .item_alignment(widget::Alignment::Start)
            .width(widget::Length::Fill);
        row.spacing = spacing;

        row.into()
    }

    pub fn default_last_view(children: Vec<BarWidgetDef<Msg>>, style: &Style) -> BarWidgetDef<Msg> {
        let spacing = style.get_last_spacing();
        let mut row = Row::new_with_children(children)
            .height(widget::Length::Fill)
            .item_alignment(widget::Alignment::End)
            .width(widget::Length::Shrink);
        row.spacing = spacing;

        row.into()
    }
}

impl<Msg> WeakBar<Msg> {
    pub fn upgrade(&self) -> Option<Bar<Msg>> {
        self.0.upgrade().map(|state| Bar { state })
    }
}

impl<Msg> BarProgram<Msg>
where
    Msg: Clone,
{
    fn view_children(children: &Arc<Mutex<Vec<Child<Msg>>>>) -> Vec<WidgetDef<BarMessage<Msg>>> {
        children
            .lock()
            .unwrap()
            .iter()
            .filter_map(Child::view)
            .collect()
    }

    fn update_children(children: Arc<Mutex<Vec<Child<Msg>>>>, msg: BarMessage<Msg>) {
        children
            .lock()
            .unwrap()
            .iter_mut()
            .for_each(move |c| c.update(msg.clone()))
    }
}

impl<Msg> Program for BarProgram<Msg>
where
    Msg: Clone + Send + 'static,
{
    type Message = BarMessage<Msg>;

    fn view(&self) -> snowcap_api::widget::WidgetDef<Self::Message> {
        let Some(bar) = self.0.upgrade() else {
            return Row::new().into();
        };

        let state = bar.state.lock().unwrap();

        let children = Self::view_children(&state.first);
        let first_view = if let Some(view) = &state.first_view {
            view(children, &state.style)
        } else {
            Bar::default_first_view(children, &state.style)
        };

        let children = Self::view_children(&state.center);
        let center_view = if let Some(view) = &state.center_view {
            view(children, &state.style)
        } else {
            Bar::default_center_view(children, &state.style)
        };

        let children = Self::view_children(&state.last);
        let last_view = if let Some(view) = &state.last_view {
            view(children, &state.style)
        } else {
            Bar::default_last_view(children, &state.style)
        };

        let mut row = Row::new_with_children([first_view, center_view, last_view])
            .item_alignment(widget::Alignment::Start)
            .height(widget::Length::Fixed(state.style.pixels));
        row.spacing = state.style.spacing;

        let padding = state.style.padding;
        let mut view = Container::new(row)
            .width(widget::Length::Fill)
            .vertical_alignment(widget::Alignment::Start)
            .horizontal_alignment(widget::Alignment::Start)
            .style(state.style.clone().into());

        view.padding = padding;

        view.into()
    }

    fn update(&mut self, msg: Self::Message) {
        use operation::{Focusable, Operation as oper};

        let Some(bar) = self.0.upgrade() else {
            return;
        };

        match msg {
            Self::Message::Empty => {
                return;
            }
            Self::Message::Operation(oper::Focusable(Focusable::Focus(id))) => {
                if let Some(handle) = bar.get_layer() {
                    let _ = handle.set_keyboard_interactivity(KeyboardInteractivity::Exclusive);
                    handle.operate(widget::operation::focusable::focus(id));
                }

                return;
            }
            Self::Message::Operation(oper::Focusable(Focusable::Unfocus)) => {
                if let Some(handle) = bar.get_layer() {
                    let _ = handle.set_keyboard_interactivity(KeyboardInteractivity::None);
                }
            }
            _ => {}
        };

        let first = bar.state.lock().unwrap().first.clone();
        let center = bar.state.lock().unwrap().center.clone();
        let last = bar.state.lock().unwrap().last.clone();

        Self::update_children(first, msg.clone());
        Self::update_children(center, msg.clone());
        Self::update_children(last, msg.clone());
    }
}

impl<Msg> Default for Bar<Msg>
where
    Msg: Clone + Send + 'static,
{
    fn default() -> Self {
        Self::new()
    }
}

impl<Msg> From<WidgetMessage> for BarMessage<Msg> {
    fn from(value: WidgetMessage) -> Self {
        if let WidgetMessage::Operation(oper) = value {
            Self::Operation(oper)
        } else {
            Self::BuiltinWidget(value)
        }
    }
}

impl<Msg> From<BarMessage<Msg>> for Option<WidgetMessage> {
    fn from(value: BarMessage<Msg>) -> Self {
        match value {
            BarMessage::Operation(oper) => Some(WidgetMessage::Operation(oper)),
            BarMessage::BuiltinWidget(w) => Some(w),
            _ => None,
        }
    }
}
