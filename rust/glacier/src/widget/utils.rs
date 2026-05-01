//! Widget utilities.
use snowcap_api::widget::{Program, WidgetDef};

/// View-only widget.
pub struct View<Msg>(Box<dyn Fn() -> WidgetDef<Msg> + Send>);

/// Create a simple view-only widget from a function.
pub fn view<F, Msg>(view: F) -> View<Msg>
where
    F: Fn() -> WidgetDef<Msg> + Send + 'static,
{
    View(Box::new(view))
}

impl<Msg> Program for View<Msg> {
    type Message = Msg;

    fn view(&self) -> Option<WidgetDef<Self::Message>> {
        Some(self.0())
    }

    fn update(&mut self, _msg: Self::Message) {}
}
