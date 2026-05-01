//! Menu's entries.
use snowcap_api::{
    signal::Signaler,
    surface::SurfaceEvent,
    widget::{
        Border, Length, Program, WidgetDef,
        column::Column,
        container::{self, Container},
        image::{self, Image},
        text,
    },
};

use crate::misc::icons;
use crate::widget::utils::{View, view};

#[derive(Clone, Debug)]
pub enum Message {
    Hover,
    Submit,
    Enable(String),
    Disable(String),
}

type Child<Msg> = Box<dyn Program<Message = Msg> + Send>;
type MenuChild<Msg> = Box<dyn WithMenu<Message = Msg> + Send>;

/// Simple label Program to be used in entries.
pub fn label<Msg>(label: impl Into<String>) -> View<Msg> {
    view({
        let label = label.into();
        move || text::Text::new(label.clone()).into()
    })
}

pub trait WithMenu: Program {
    /// Called by Entry to open a menu.
    fn open_menu(&self) -> Option<super::Menu<Self::Message>>;
}

enum Kind<Msg> {
    Menu(MenuChild<Msg>),
    Standard(Child<Msg>),
    Separator,
}

/// [`Menu`]'s `Entry`.
pub struct Entry<Msg> {
    id: Option<String>,
    kind: Kind<Msg>,
    disabled: bool,
    close_on_submit: bool,
}

impl<Msg> Entry<Msg> {
    /// Build a new standard [`Entry`].
    pub fn standard<C>(child: C) -> Self
    where
        C: Program<Message = Msg> + Send + 'static,
    {
        Self {
            id: None,
            kind: Kind::Standard(Box::new(child)),
            disabled: false,
            close_on_submit: true,
        }
    }

    /// Build a new Menu [`Entry`].
    pub fn menu<C>(child: C) -> Self
    where
        C: WithMenu<Message = Msg> + Send + 'static,
    {
        Self {
            id: None,
            kind: Kind::Menu(Box::new(child)),
            disabled: false,
            close_on_submit: false,
        }
    }

    /// Build a new separator [`Entry`].
    pub fn separator() -> Self {
        Self {
            id: None,
            kind: Kind::Separator,
            disabled: true,
            close_on_submit: false,
        }
    }

    /// Sets the entry id.
    pub fn id(self, id: impl Into<String>) -> Self {
        Self {
            id: Some(id.into()),
            ..self
        }
    }

    /// Disable the entry.
    pub fn disable(self) -> Self {
        Self {
            disabled: true,
            ..self
        }
    }

    /// Set the close_on_submit flag.
    pub fn close_on_submit(self, close_on_submit: bool) -> Self {
        Self {
            close_on_submit,
            ..self
        }
    }

    /// Check whether the [`Entry`] is disabled.
    pub fn is_disabled(&self) -> bool {
        matches!(self.kind, Kind::Separator) || self.disabled
    }

    /// Check whether the [`Entry`] is a standard [`Entry`].
    pub fn is_standard(&self) -> bool {
        matches!(self.kind, Kind::Standard(_))
    }

    /// Check whether the [`Entry`] is a menu [`Entry`].
    pub fn is_menu(&self) -> bool {
        matches!(self.kind, Kind::Menu(_))
    }

    /// Check whether the [`Entry`] is a separator.
    pub fn is_separator(&self) -> bool {
        matches!(self.kind, Kind::Separator)
    }

    /// Check whether the [`Entry`] must close after it's submitted.
    pub fn should_close_on_submit(&self) -> bool {
        self.is_standard() && self.close_on_submit
    }

    /// Render a separator
    pub(super) fn separator_view(style: &super::style::Separator) -> WidgetDef<Msg> {
        let separator = Container::new(Column::new())
            .width(Length::Fill)
            .height(Length::Fixed(style.thickness))
            .style(container::Style {
                background: style.bg_color.map(From::from),
                border: Some(Border {
                    color: style.fg_color,
                    width: Some(style.thickness),
                    radius: None,
                }),
                ..Default::default()
            });

        let container = Container::new(separator).padding(style.padding);

        container.into()
    }

    /// Render the menu-indicator icon.
    pub(super) fn menu_indicator_view(
        style: &super::style::MenuIndicator,
        disabled: bool,
        selected: bool,
    ) -> WidgetDef<Msg> {
        let fg_color = if disabled {
            style.color_disabled.or(style.color)
        } else if selected {
            style.color_selected.or(style.color)
        } else {
            style.color
        };

        let icon_handle = icons::menu::menu_indicator().to_image_handle(fg_color);
        let mut icon = Image::new(icon_handle).content_fit(image::ContentFit::ScaleDown);

        icon.height = style.height;
        icon.width = style.width;

        icon.into()
    }

    pub(super) fn open_menu(&self) -> Option<super::Menu<Msg>> {
        match &self.kind {
            Kind::Menu(m) => m.open_menu(),
            _ => None,
        }
    }

    fn update_child(&mut self, msg: Msg) {
        match &mut self.kind {
            Kind::Menu(m) => m.update(msg),
            Kind::Standard(s) => s.update(msg),
            Kind::Separator => (),
        }
    }
}

impl<Msg> Program for Entry<Msg>
where
    Msg: TryInto<super::Message> + From<super::Message> + Clone + 'static,
{
    type Message = Msg;

    fn view(&self) -> Option<snowcap_api::widget::WidgetDef<Self::Message>> {
        match &self.kind {
            Kind::Menu(m) => m.view(),
            Kind::Standard(s) => s.view(),
            _ => None,
        }
    }

    fn update(&mut self, msg: Self::Message) {
        use super::Message as MenuMsg;
        let is_standard = self.is_standard();

        if matches!(self.kind, Kind::Separator) {
            return;
        }

        let entry_msg = match msg.clone().try_into() {
            Err(_) => {
                self.update_child(msg);
                return;
            }
            Ok(MenuMsg::Menu { .. }) => {
                return;
            }
            Ok(MenuMsg::Entry(msg)) => msg,
        };

        match entry_msg {
            Message::Submit if is_standard => {
                self.update_child(msg);
            }
            Message::Hover => {
                self.update_child(msg);
            }
            Message::Enable(id) if Some(id.as_str()) == self.id.as_deref() => {
                self.disabled = false;
            }
            Message::Disable(id) if Some(id.as_str()) == self.id.as_deref() => {
                self.disabled = false;
            }
            _ => (),
        };
    }

    fn event(&mut self, event: snowcap_api::surface::SurfaceEvent<Self::Message>) {
        match &mut self.kind {
            Kind::Menu(m) => m.event(event),
            Kind::Standard(s) => s.event(event),
            Kind::Separator => (),
        }
    }

    fn signaler(&self) -> Option<snowcap_api::signal::Signaler> {
        match &self.kind {
            Kind::Menu(m) => m.signaler(),
            Kind::Standard(s) => s.signaler(),
            Kind::Separator => None,
        }
    }
}

type SubmitCallback = Box<dyn FnMut() + Send>;
struct Standard<Msg> {
    child: Child<Msg>,
    callback: SubmitCallback,
}

/// Create a standard entry using a callback on submit.
pub fn standard<Msg, C, F>(child: C, submit: F) -> Entry<Msg>
where
    Msg: TryInto<super::Message> + Clone + 'static,
    C: Program<Message = Msg> + Send + 'static,
    F: FnMut() + Send + 'static,
{
    let program = Standard {
        child: Box::new(child),
        callback: Box::new(submit),
    };

    Entry::standard(program)
}

impl<Msg> Program for Standard<Msg>
where
    Msg: TryInto<super::Message> + Clone,
{
    type Message = Msg;

    fn view(&self) -> Option<WidgetDef<Self::Message>> {
        self.child.view()
    }

    fn event(&mut self, event: SurfaceEvent<Self::Message>) {
        self.child.event(event)
    }

    fn signaler(&self) -> Option<Signaler> {
        self.child.signaler()
    }

    fn update(&mut self, msg: Self::Message) {
        if let Ok(Message::Submit) = msg
            .clone()
            .try_into()
            .map_err(|_| ())
            .and_then(|msg: super::Message| msg.try_into())
        {
            (self.callback)()
        } else {
            self.child.update(msg);
        }
    }
}

type OpenCallback<Msg> = Box<dyn Fn() -> super::Menu<Msg> + Send>;
struct Submenu<Msg> {
    child: Child<Msg>,
    callback: OpenCallback<Msg>,
    signaler: Option<Signaler>,
}

/// Create an [`Entry`] using a callback to open the menu.
pub fn submenu<Msg, C, F>(child: C, on_open: F) -> Entry<Msg>
where
    Msg: TryInto<super::Message> + Clone + Send + 'static,
    C: Program<Message = Msg> + Send + 'static,
    F: Fn() -> super::Menu<Msg> + Send + 'static,
{
    let signaler = if child.signaler().is_none() {
        Some(Signaler::new())
    } else {
        None
    };

    let program = Submenu {
        child: Box::new(child),
        callback: Box::new(on_open),
        signaler,
    };

    Entry::menu(program)
}

impl<Msg> Program for Submenu<Msg>
where
    Msg: TryInto<super::Message> + Clone + Send + 'static,
{
    type Message = Msg;

    fn view(&self) -> Option<WidgetDef<Self::Message>> {
        self.child.view()
    }

    fn event(&mut self, event: snowcap_api::surface::SurfaceEvent<Self::Message>) {
        self.child.event(event);
    }

    fn signaler(&self) -> Option<Signaler> {
        self.child.signaler().or(self.signaler.clone())
    }

    fn update(&mut self, msg: Self::Message) {
        self.child.update(msg);
    }
}

impl<Msg> WithMenu for Submenu<Msg>
where
    Msg: TryInto<super::Message> + Clone + Send + 'static,
{
    fn open_menu(&self) -> Option<super::Menu<Msg>> {
        Some((self.callback)())
    }
}

/// Create a separator [`Entry`].
pub fn separator<Msg>() -> Entry<Msg> {
    Entry::separator()
}

impl TryFrom<super::Message> for Message {
    type Error = ();

    fn try_from(value: super::Message) -> Result<Self, Self::Error> {
        if let super::Message::Entry(msg) = value {
            Ok(msg)
        } else {
            Err(())
        }
    }
}
