//! Bar children.
use snowcap_api::{popup::Parent, widget::WidgetDef};

use crate::{
    signal::TryWithEmitter,
    widget::{Functional, Widget, WithState},
};

use super::BarMessage;

/// Bar child.
///
/// [`Child`] holds either a view callback, or a full fledge stateful [`Widget`].
///
/// The preferred way to construct [`Child`] is through the use of the [`children`] macro, which
/// accept any type that can be turned into a `Child` via the [`Into<Child>`] traits. Blankets
/// implementation are provided for type implementing [`WithState`].
pub enum Child<Msg> {
    /// Functional-style stateless widget.
    Functional(Box<dyn Fn() -> WidgetDef<BarMessage<Msg>> + Sync + Send + 'static>),
    /// Stateful widgets.
    Widget(Box<dyn Widget<Message = BarMessage<Msg>> + Sync + Send + 'static>),
}

impl<Msg> Child<Msg>
where
    Msg: Clone,
{
    /// Calls update on stateful widgets.
    fn update_inner(&mut self, msg: BarMessage<Msg>, parent: Option<Parent>) {
        if let Self::Widget(w) = self {
            w.update(msg, parent)
        }
    }

    /// Render the contained [`Widget`].
    pub(crate) fn view(&self) -> Option<snowcap_api::widget::WidgetDef<BarMessage<Msg>>> {
        match self {
            Self::Functional(cb) => Some(cb()),
            Self::Widget(w) => w.view(),
        }
    }

    /// Update held [`Widget`].
    pub(crate) fn update(&mut self, msg: BarMessage<Msg>, parent: Option<Parent>) {
        match msg {
            BarMessage::Empty => {}
            _ => self.update_inner(msg, parent),
        }
    }
}

impl<Msg> TryWithEmitter for Child<Msg> {
    fn try_with_emitter(&self) -> Option<crate::signal::Emitter> {
        match self {
            Self::Functional(_) => None,
            Self::Widget(w) => w.try_with_emitter(),
        }
    }
}

impl<T, Msg> From<T> for Child<Msg>
where
    T: WithState,
    T::Type: Widget<Message = BarMessage<Msg>> + TryWithEmitter + Sync + Send + 'static,
{
    fn from(value: T) -> Self {
        Self::Widget(Box::new(value.with_state()))
    }
}

impl<F, Msg> From<Functional<F, BarMessage<Msg>>> for Child<Msg>
where
    F: Fn() -> WidgetDef<BarMessage<Msg>> + Sync + Send + 'static,
{
    fn from(value: Functional<F, BarMessage<Msg>>) -> Self {
        Self::Functional(Box::new(value.0))
    }
}

/// Create a [`Vec`] of [`Child`].
///
/// `children!` allows to create a `Vec` of `Child` from disjointed types, with the same syntax as
/// array expressions.
///
/// It supports all elements which implement [`Into<Child>`].
#[macro_export]
macro_rules! children {
    () => [
        std::vec::Vec::new()
    ];
    ($($child:expr),+ $(,)?) => [
        vec![
            $($child.into()),*
        ]
    ];
}

pub use children;
