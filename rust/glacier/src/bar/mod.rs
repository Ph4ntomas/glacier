//! Glacier's bar.
//!
//! The [`Bar`] is split into 3 area, referred to as `first`, `center` and `last`. By default, the
//! bar sits on top of the screen, and render each area left to right, with the following rules:
//!  - first: the area shrink to fit its content, which is left-aligned.
//!  - center: The area fill the remaining space. Its content is left aligned.
//!  - right: The area shrink to fit its content, which is right-aligned.
//! ```text
//!  -------------------------------------------------------
//!  | first    |             center             |    last |
//!  -------------------------------------------------------
//! ```
//!
//! When a new view is needed, the bar starts by calling the view function for each of its children,
//! filtering out children whose view is [`None`]. It then render each areas calling their view
//! function, passing both the children for this area and the [`Bar`]'s [`Style`]. The three
//! resulting views are put in a container spanning the whole screen.
//!

use std::num::NonZero;

use crate::misc;

use snowcap_api::{
    input::KeyEvent,
    layer::{self, LayerHandle},
    signal::{HandlerPolicy, Signaler},
    surface::SurfaceHandle,
    widget::{self, Program, WidgetDef, base::WidgetBase, container, row},
};

#[doc(inline)]
pub use crate::programs;

pub mod style;
#[doc(inline)]
pub use style::Style;

type Child<Msg> = Box<dyn Program<Message = Msg> + Send + 'static>;
type ViewCallback<Msg> = Box<dyn Fn(Vec<WidgetDef<Msg>>, &Style) -> WidgetDef<Msg> + Send>;

/// Bar's default style.
pub fn default_style() -> Style {
    Style::new()
        .pixels(24.)
        .padding(widget::Padding::from(8.))
        .bg_color(misc::color::from_hex("#1a1a1a"))
}

/// A handle to a standalone [`Bar`].
pub struct Handle<Msg> {
    handle: LayerHandle<Msg>,
}

/// Glacier's bar.
///
/// See module level [documentation].
///
/// [documentation]: self
pub struct Bar<Msg> {
    base: WidgetBase,
    handle: Option<SurfaceHandle<Msg>>,

    style: Style,

    first: Vec<Box<dyn Program<Message = Msg> + Send + 'static>>,
    center: Vec<Box<dyn Program<Message = Msg> + Send + 'static>>,
    last: Vec<Box<dyn Program<Message = Msg> + Send + 'static>>,

    first_view: Option<ViewCallback<Msg>>,
    center_view: Option<ViewCallback<Msg>>,
    last_view: Option<ViewCallback<Msg>>,
}

impl<Msg> Bar<Msg> {
    /// Default view function for the first area.
    pub fn default_first_view(children: Vec<WidgetDef<Msg>>, style: &Style) -> WidgetDef<Msg> {
        let spacing = style.get_first_spacing();
        let mut row = row::Row::new_with_children(children)
            .height(widget::Length::Fill)
            .width(widget::Length::Shrink)
            .item_alignment(widget::Alignment::Start);
        row.spacing = spacing;

        row.into()
    }

    /// Default view function for the center area.
    pub fn default_center_view(children: Vec<WidgetDef<Msg>>, style: &Style) -> WidgetDef<Msg> {
        let spacing = style.get_center_spacing();
        let mut row = row::Row::new_with_children(children)
            .height(widget::Length::Fill)
            .width(widget::Length::Fill)
            .item_alignment(widget::Alignment::Start);
        row.spacing = spacing;

        row.into()
    }

    /// Default view function for the last area.
    pub fn default_last_view(children: Vec<WidgetDef<Msg>>, style: &Style) -> WidgetDef<Msg> {
        let spacing = style.get_last_spacing();
        let mut row = row::Row::new_with_children(children)
            .height(widget::Length::Fill)
            .width(widget::Length::Shrink)
            .item_alignment(widget::Alignment::End);
        row.spacing = spacing;

        row.into()
    }
}

impl<Msg> Handle<Msg> {
    /// Request keyboard focus for this [`Bar`].
    pub fn focus(&self) {
        let _ = self
            .handle
            .set_keyboard_interactivity(layer::KeyboardInteractivity::Exclusive);
    }

    /// Remove keyboard focus for the [`Bar`].
    pub fn unfocus(&self) {
        let _ = self
            .handle
            .set_keyboard_interactivity(layer::KeyboardInteractivity::None);
    }

    /// Send an arbitrary `Msg`.
    pub fn send_message(&self, message: impl Into<Msg>) {
        self.handle.send_message(message.into());
    }

    /// Access the underlying [`LayerHandle`].
    pub fn layer(&self) -> &LayerHandle<Msg> {
        &self.handle
    }

    /// Access the underlying [`LayerHandle`].
    pub fn layer_mut(&mut self) -> &mut LayerHandle<Msg> {
        &mut self.handle
    }
}

impl<Msg> Handle<Msg>
where
    Msg: Clone + Send + 'static,
{
    /// Sets the backing surface key event handler.
    pub fn on_key_event(&self, mut on_event: impl FnMut(Handle<Msg>, KeyEvent) + Send + 'static) {
        self.handle.on_key_event({
            move |handle, event| {
                on_event(Self { handle }, event);
            }
        })
    }
}

impl<Msg> Bar<Msg> {
    const PROGRAM_TYPE: &str = "glacier::bar::BarProgram";

    /// Create a new `Bar`.
    pub fn new() -> Self {
        Self {
            base: WidgetBase::new(Self::PROGRAM_TYPE),
            handle: None,

            style: default_style(),

            first: Default::default(),
            center: Default::default(),
            last: Default::default(),

            first_view: None,
            center_view: None,
            last_view: None,
        }
    }

    /// Connect to a specific [`Signal`].
    ///
    /// [`Signal`]: snowcap_api::signal::Signal
    pub fn connect<S, F>(&self, callback: F) -> snowcap_api::signal::Handle<S>
    where
        S: snowcap_api::signal::Signal,
        F: Fn(S) -> HandlerPolicy + Sync + Send + 'static,
    {
        self.base.signaler().connect(callback)
    }

    /// Access the bar [`Signaler`].
    pub fn signaler(&self) -> Signaler {
        self.base.signaler()
    }

    /// Sets the bar's [`Style`]
    pub fn style(self, style: Style) -> Self {
        Self { style, ..self }
    }

    /// Sets the children in the first area.
    pub fn first(self, children: impl IntoIterator<Item = Child<Msg>>) -> Self {
        Self {
            first: children.into_iter().collect(),
            ..self
        }
    }

    /// Sets the children in the center area.
    pub fn center(self, children: impl IntoIterator<Item = Child<Msg>>) -> Self {
        Self {
            center: children.into_iter().collect(),
            ..self
        }
    }

    /// Sets the children in the last area.
    pub fn last(self, children: impl IntoIterator<Item = Child<Msg>>) -> Self {
        Self {
            last: children.into_iter().collect(),
            ..self
        }
    }

    /// Override the view function for the first area.
    pub fn first_view<F>(self, callback: F) -> Self
    where
        F: Fn(Vec<WidgetDef<Msg>>, &Style) -> WidgetDef<Msg> + Send + 'static,
    {
        Self {
            first_view: Some(Box::new(callback)),
            ..self
        }
    }

    /// Override the view function for the central area.
    pub fn center_view<F>(self, callback: F) -> Self
    where
        F: Fn(Vec<WidgetDef<Msg>>, &Style) -> WidgetDef<Msg> + Send + 'static,
    {
        Self {
            center_view: Some(Box::new(callback)),
            ..self
        }
    }

    /// Override the view function for the last area.
    pub fn last_view<F>(self, callback: F) -> Self
    where
        F: Fn(Vec<WidgetDef<Msg>>, &Style) -> WidgetDef<Msg> + Send + 'static,
    {
        Self {
            last_view: Some(Box::new(callback)),
            ..self
        }
    }

    fn get_exclusive_size(&self) -> NonZero<u32> {
        let padding_sz = self.style.padding.map(|p| p.top + p.bottom).unwrap_or(0.0);

        let sum_dimension = self.style.pixels + padding_sz;

        let exclusive = u32::max(1, sum_dimension as u32);

        NonZero::new(exclusive).unwrap()
    }

    fn iter_children(&self) -> impl Iterator<Item = &Child<Msg>> {
        self.first
            .iter()
            .chain(self.center.iter())
            .chain(self.last.iter())
    }

    fn iter_children_mut(&mut self) -> impl Iterator<Item = &mut Child<Msg>> {
        self.first
            .iter_mut()
            .chain(self.center.iter_mut())
            .chain(self.last.iter_mut())
    }
}

impl<Msg> Bar<Msg>
where
    Msg: Clone + Send + 'static,
{
    /// Create a [`layer`] to display the `Bar` as a standalone program.
    pub fn show(self) -> Handle<Msg> {
        let exclusive = self.get_exclusive_size();

        let handle = layer::new_widget(
            self,
            Some(layer::Anchor::Top),
            layer::KeyboardInteractivity::None,
            layer::ExclusiveZone::Exclusive(exclusive),
            layer::ZLayer::Top,
        )
        .expect("Could not create Layer for this bar.");

        Handle { handle }
    }
}

impl<Msg> Program for Bar<Msg>
where
    Msg: Clone + 'static,
{
    type Message = Msg;

    fn view(&self) -> Option<snowcap_api::widget::WidgetDef<Self::Message>> {
        let first = self.first.iter().filter_map(Program::view).collect();
        let first_view = if let Some(view) = self.first_view.as_ref() {
            view(first, &self.style)
        } else {
            Bar::default_first_view(first, &self.style)
        };

        let center = self.center.iter().filter_map(Program::view).collect();
        let center_view = if let Some(view) = self.center_view.as_ref() {
            view(center, &self.style)
        } else {
            Bar::default_center_view(center, &self.style)
        };

        let last = self.last.iter().filter_map(Program::view).collect();
        let last_view = if let Some(view) = self.last_view.as_ref() {
            view(last, &self.style)
        } else {
            Bar::default_last_view(last, &self.style)
        };

        let mut row = row::Row::new_with_children([first_view, center_view, last_view])
            .item_alignment(widget::Alignment::Start)
            .height(widget::Length::Fixed(self.style.pixels));
        row.spacing = self.style.spacing;

        let padding = self.style.padding;
        let mut view = container::Container::new(row)
            .width(widget::Length::Fill)
            .vertical_alignment(widget::Alignment::Start)
            .horizontal_alignment(widget::Alignment::Start)
            .style(self.style.clone().into());
        view.padding = padding;

        Some(view.into())
    }

    fn event(&mut self, event: snowcap_api::surface::SurfaceEvent<Self::Message>) {
        use snowcap_api::surface::SurfaceEvent;

        match &event {
            SurfaceEvent::Created { surface } => {
                self.handle = Some(surface.clone());

                self.iter_children().for_each(|c| self.register_child(c));
            }
            SurfaceEvent::Closing => self
                .base
                .signaler()
                .emit(snowcap_api::widget::signal::Closed),
            _ => {}
        }

        self.iter_children_mut()
            .for_each(|c| c.event(event.clone()));
    }

    fn update(&mut self, msg: Self::Message) {
        self.iter_children_mut().for_each(|c| c.update(msg.clone()));
    }

    fn signaler(&self) -> Option<snowcap_api::signal::Signaler> {
        Some(self.base.signaler())
    }
}

impl<Msg> Default for Bar<Msg> {
    fn default() -> Self {
        Self::new()
    }
}

impl<Msg> Clone for Handle<Msg> {
    fn clone(&self) -> Self {
        Self {
            handle: self.handle.clone(),
        }
    }
}
