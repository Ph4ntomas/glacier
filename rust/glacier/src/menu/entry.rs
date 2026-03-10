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

#[derive(Clone, Debug)]
pub enum Message {
    Hover,
    OpenMenu,
    Submit,
    Enable(String),
    Disable(String),
}

type Child<Msg> = Box<dyn Program<Message = Msg> + Send>;

pub struct View<Msg>(Box<dyn Fn() -> WidgetDef<Msg> + Send>);

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

pub fn label<Msg>(label: impl Into<String>) -> View<Msg> {
    view({
        let label = label.into();
        move || text::Text::new(label.clone()).into()
    })
}

enum Kind<Msg> {
    Menu(Child<Msg>),
    Standard(Child<Msg>),
    Separator,
}

pub struct Entry<Msg> {
    id: Option<String>,
    kind: Kind<Msg>,
    disabled: bool,
    close_on_submit: bool,
}

impl<Msg> Entry<Msg> {
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

    pub fn menu<C>(child: C) -> Self
    where
        C: Program<Message = Msg> + Send + 'static,
    {
        Self {
            id: None,
            kind: Kind::Menu(Box::new(child)),
            disabled: false,
            close_on_submit: false,
        }
    }

    pub fn separator() -> Self {
        Self {
            id: None,
            kind: Kind::Separator,
            disabled: true,
            close_on_submit: false,
        }
    }

    pub fn id(self, id: impl Into<String>) -> Self {
        Self {
            id: Some(id.into()),
            ..self
        }
    }

    pub fn disable(self) -> Self {
        Self {
            disabled: true,
            ..self
        }
    }

    pub fn close_on_submit(self, close_on_submit: bool) -> Self {
        Self {
            close_on_submit,
            ..self
        }
    }

    pub fn is_disabled(&self) -> bool {
        matches!(self.kind, Kind::Separator) || self.disabled
    }

    pub fn is_standard(&self) -> bool {
        matches!(self.kind, Kind::Standard(_))
    }

    pub fn is_menu(&self) -> bool {
        matches!(self.kind, Kind::Menu(_))
    }

    pub fn is_separator(&self) -> bool {
        matches!(self.kind, Kind::Separator)
    }

    pub fn should_close_on_submit(&self) -> bool {
        self.is_standard() && self.close_on_submit
    }

    fn child(&self) -> Option<&Child<Msg>> {
        match &self.kind {
            Kind::Standard(c) | Kind::Menu(c) => Some(c),
            _ => None,
        }
    }

    fn child_mut(&mut self) -> Option<&mut Child<Msg>> {
        match &mut self.kind {
            Kind::Standard(c) | Kind::Menu(c) => Some(c),
            Kind::Separator => None,
        }
    }

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
}

impl<Msg> Program for Entry<Msg>
where
    Msg: TryInto<super::Message> + From<super::Message> + Clone + 'static,
{
    type Message = Msg;

    fn view(&self) -> Option<snowcap_api::widget::WidgetDef<Self::Message>> {
        self.child().and_then(|c| c.view())
    }

    fn update(&mut self, msg: Self::Message) {
        use super::Message as MenuMsg;
        let is_menu = self.is_menu();
        let is_standard = self.is_standard();

        if let Some(child) = self.child_mut() {
            let entry_msg = match msg.clone().try_into() {
                Err(_) => {
                    child.update(msg);
                    return;
                }
                Ok(MenuMsg::Menu { .. }) => {
                    return;
                }
                Ok(MenuMsg::Entry(msg)) => msg,
            };

            match entry_msg {
                Message::Submit | Message::OpenMenu if is_menu => {
                    child.update(super::Message::Entry(Message::OpenMenu).into());
                }
                Message::Submit if is_standard => {
                    child.update(msg);
                }
                Message::Hover => {
                    child.update(msg);
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
    }

    fn event(&mut self, event: snowcap_api::surface::SurfaceEvent<Self::Message>) {
        if let Some(child) = self.child_mut() {
            child.event(event);
        }
    }

    fn signaler(&self) -> Option<snowcap_api::signal::Signaler> {
        self.child().and_then(|c| c.signaler())
    }
}

type SubmitCallback = Box<dyn FnMut() + Send>;
struct Standard<Msg> {
    child: Child<Msg>,
    callback: SubmitCallback,
}

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
        if msg.clone().try_into().is_ok() {
            let menu = (self.callback)();

            self.signaler()
                .unwrap()
                .emit(super::signal::RequestSubmenuOpen::new(menu));
        } else {
            self.child.update(msg);
        }
    }
}

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
