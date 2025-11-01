use snowcap_api::widget::WidgetDef;

use crate::{
    bar::BarMessage,
    signal::TryWithEmitter,
    widget::{Widget, WithState},
};

pub enum Child<Msg> {
    Functional(Box<dyn Fn() -> WidgetDef<BarMessage<Msg>> + Sync + Send + 'static>),
    Widget(Box<dyn Widget<Message = BarMessage<Msg>> + Sync + Send + 'static>),
}

///Disambiguisation marker for functional-style children.
pub struct Functional<F, Msg>(pub F)
where
    F: Fn() -> WidgetDef<BarMessage<Msg>> + Sync + Send + 'static;

impl<Msg> Child<Msg>
where
    Msg: Clone,
{
    fn update_inner(&mut self, msg: BarMessage<Msg>) {
        if let Self::Widget(w) = self {
            w.update(msg)
        }
    }

    pub(crate) fn view(&self) -> Option<snowcap_api::widget::WidgetDef<BarMessage<Msg>>> {
        match self {
            Self::Functional(cb) => Some(cb()),
            Self::Widget(w) => w.view(),
        }
    }

    pub(crate) fn update(&mut self, msg: BarMessage<Msg>) {
        match msg {
            BarMessage::Empty => {}
            _ => self.update_inner(msg),
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

impl<F, Msg> From<Functional<F, Msg>> for Child<Msg>
where
    F: Fn() -> WidgetDef<BarMessage<Msg>> + Sync + Send + 'static,
{
    fn from(value: Functional<F, Msg>) -> Self {
        Self::Functional(Box::new(value.0))
    }
}

#[macro_export]
macro_rules! children {
    ($($child:expr), *) => [
        vec![
            $($child.into()),*
        ]
    ];
}

pub use children;
