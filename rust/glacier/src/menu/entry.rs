//! Menu children/

use std::marker::PhantomData;

use snowcap_api::{
    popup::Parent,
    widget::{
        Alignment, Border, Length, Padding,
        column::Column,
        container::{self, Container},
        image::{self, Image},
        row::Row,
        text::{self, Text},
    },
};

use crate::{
    color,
    menu::{
        Action, Menu, MenuMessage,
        entry::style::{EntryStyle, SeparatorStyle},
    },
    misc::icons,
    signal::TryWithEmitter,
};

pub mod style;
#[doc(inline)]
pub use style::Style;

pub fn default_style() -> Style {
    Style {
        font_size: None,
        font: None,
        default: style::EntryStyle {
            fg_color: Some(color::from_hex("#d7d7d7")),
            padding: Some(Padding {
                left: 2.,
                right: 2.,
                ..Default::default()
            }),
            ..Default::default()
        },
        active: Some(style::EntryStyle {
            bg_color: Some(color::from_hex("#6B1ABC")),
            ..Default::default()
        }),
        disabled: Some(style::EntryStyle {
            fg_color: Some(color::from_hex("#5b5b5b")),
            ..Default::default()
        }),
        menu_indicator: Some(style::MenuIndicatorStyle {
            width: Some(Length::Fixed(12.)),
            height: Some(Length::Fixed(12.)),
            color: Some(color::from_hex("#7b7b7b")),
        }),
        separator: Some(style::SeparatorStyle {
            fg_color: Some(color::from_hex("#131313")),
            height: Some(Length::Fixed(1.)),
            padding: Some(Padding {
                top: 3.,
                right: 3.,
                bottom: 8.,
                left: 8.,
            }),
            thickness: Some(1.),
            ..Default::default()
        }),
    }
}

pub fn default_entry_view<Msg>(
    entry: &impl Entry,
    active: bool,
    style: &Style,
) -> Option<snowcap_api::widget::WidgetDef<Msg>> {
    let EntryStyle {
        fg_color,
        bg_color,
        height,
        padding,
        border,
    } = EntryState::from_entry(entry, active).get_entry_style(style);

    let label = Text::new(entry.label())
        .style(text::Style {
            color: fg_color,
            font: style.font.clone(),
            pixels: style.font_size,
        })
        .width(Length::Fill);

    let mut container = Container::new(label)
        .clip(true)
        .style(container::Style {
            background: bg_color.map(From::from),
            border,
            ..Default::default()
        })
        .vertical_alignment(Alignment::Center);

    container.padding = padding;
    container.height = height;
    container.width = Some(Length::Fill);

    Some(container.into())
}

pub fn default_menu_view<Msg>(
    entry: &impl Entry,
    active: bool,
    style: &Style,
) -> Option<snowcap_api::widget::WidgetDef<Msg>> {
    let EntryStyle {
        fg_color,
        bg_color,
        height,
        padding,
        border,
    } = EntryState::from_entry(entry, active).get_entry_style(style);
    let icon_style = style.menu_indicator.clone().unwrap_or_default();

    let label = Text::new(entry.label())
        .style(text::Style {
            color: fg_color,
            font: style.font.clone(),
            pixels: style.font_size,
        })
        .width(Length::Fill);

    let icon_handle = icons::menu::menu_indicator().to_image_handle(icon_style.color.or(fg_color));
    let mut icon = Image::new(icon_handle).content_fit(image::ContentFit::ScaleDown);

    icon.height = icon_style.height;
    icon.width = icon_style.width;

    let mut container = Container::new(
        Row::new_with_children([label.into(), icon.into()]).item_alignment(Alignment::Center),
    )
    .clip(true)
    .style(container::Style {
        background: bg_color.map(From::from),
        border,
        ..Default::default()
    })
    .vertical_alignment(Alignment::Center);

    container.padding = padding;
    container.height = height;
    container.width = Some(Length::Fill);

    Some(container.into())
}

#[derive(Debug, Clone, Copy)]
pub enum EntryState {
    Active,
    Disabled,
    Default,
}

impl EntryState {
    pub fn from_entry(entry: &impl Entry, active: bool) -> Self {
        if entry.disabled() {
            Self::Disabled
        } else if active {
            Self::Active
        } else {
            Self::Default
        }
    }

    pub fn get_entry_style(self, style: &Style) -> style::EntryStyle {
        let default = style.default.clone();

        let EntryStyle {
            fg_color,
            bg_color,
            height,
            padding,
            border,
        } = match self {
            Self::Default => {
                return default;
            }
            Self::Active => style.active.clone().unwrap_or_default(),
            Self::Disabled => style.disabled.clone().unwrap_or_default(),
        };

        EntryStyle {
            fg_color: fg_color.or(default.fg_color),
            bg_color: bg_color.or(default.bg_color),
            height: height.or(default.height),
            padding: padding.or(default.padding),
            border: border.or(default.border),
        }
    }
}

pub trait Entry: TryWithEmitter {
    type Message: Clone;
    type Menu;

    fn key(&self) -> &str;
    fn set_key(&mut self, key: String);

    fn activate(&mut self, hover: bool) -> Option<Self::Message> {
        let _ = hover;
        None
    }

    fn deactivate(&mut self) {}

    fn label(&self) -> &str;
    fn disabled(&self) -> bool {
        true
    }

    fn view(
        &self,
        active: bool,
        style: &Style,
    ) -> Option<snowcap_api::widget::WidgetDef<Self::Message>>;

    fn update(&mut self, msg: Self::Message, parent: Option<Parent>) {
        let _ = msg;
        let _ = parent;
    }

    fn submit(&self) -> Option<Self::Message> {
        None
    }

    fn open_menu(&self) -> Option<Self::Menu> {
        None
    }
}

pub struct SimpleEntry<Msg> {
    key: String,
    label: String,
    on_submit: Option<Box<dyn Fn() -> Option<MenuMessage<Msg>> + Sync + Send>>,
}

impl<Msg> SimpleEntry<Msg> {
    pub fn new<F>(label: impl ToString, on_submit: F) -> Self
    where
        F: Fn() -> Option<MenuMessage<Msg>> + Sync + Send + 'static,
    {
        Self {
            key: Default::default(),
            label: label.to_string(),
            on_submit: Some(Box::new(on_submit)),
        }
    }

    pub fn new_from_part<F>(label: impl ToString, on_submit: Option<F>) -> Self
    where
        F: Fn() -> Option<MenuMessage<Msg>> + Sync + Send + 'static,
    {
        Self {
            key: Default::default(),
            label: label.to_string(),
            on_submit: if let Some(on_submit) = on_submit {
                Some(Box::new(on_submit))
            } else {
                None
            },
        }
    }

    pub fn new_disabled(label: impl ToString) -> Self {
        Self {
            key: Default::default(),
            label: label.to_string(),
            on_submit: None,
        }
    }
}

impl<Msg> TryWithEmitter for SimpleEntry<Msg> {
    fn try_with_emitter(&self) -> Option<crate::signal::Emitter> {
        None
    }
}

impl<Msg> Entry for SimpleEntry<Msg>
where
    Msg: Clone,
{
    type Message = MenuMessage<Msg>;
    type Menu = Menu<Msg>;

    fn key(&self) -> &str {
        &self.key
    }

    fn set_key(&mut self, key: String) {
        self.key = key;
    }

    fn label(&self) -> &str {
        &self.label
    }

    fn disabled(&self) -> bool {
        self.on_submit.is_none()
    }

    fn submit(&self) -> Option<Self::Message> {
        let on_submit = self.on_submit.as_ref()?;

        on_submit().or(Some(Action::Close.into()))
    }

    fn view(
        &self,
        active: bool,
        style: &Style,
    ) -> Option<snowcap_api::widget::WidgetDef<Self::Message>> {
        default_entry_view(self, active, style)
    }
}

pub struct SimpleMenu<Msg> {
    key: String,
    label: String,
    on_open_menu: Option<Box<dyn Fn() -> Option<Menu<Msg>> + Sync + Send>>,
}

impl<Msg> SimpleMenu<Msg> {
    pub fn new<F>(label: impl ToString, on_open_menu: F) -> Self
    where
        F: Fn() -> Option<Menu<Msg>> + Sync + Send + 'static,
    {
        Self {
            key: Default::default(),
            label: label.to_string(),
            on_open_menu: Some(Box::new(on_open_menu)),
        }
    }

    pub fn new_from_part<F>(label: impl ToString, on_open_menu: Option<F>) -> Self
    where
        F: Fn() -> Option<Menu<Msg>> + Sync + Send + 'static,
    {
        Self {
            key: Default::default(),
            label: label.to_string(),
            on_open_menu: if let Some(on_open_menu) = on_open_menu {
                Some(Box::new(on_open_menu))
            } else {
                None
            },
        }
    }

    pub fn new_disabled(label: impl ToString) -> Self {
        Self {
            key: Default::default(),
            label: label.to_string(),
            on_open_menu: None,
        }
    }
}

impl<Msg> TryWithEmitter for SimpleMenu<Msg> {
    fn try_with_emitter(&self) -> Option<crate::signal::Emitter> {
        None
    }
}

impl<Msg> Entry for SimpleMenu<Msg>
where
    Msg: Clone,
{
    type Message = MenuMessage<Msg>;
    type Menu = Menu<Msg>;

    fn key(&self) -> &str {
        &self.key
    }

    fn set_key(&mut self, key: String) {
        self.key = key;
    }

    fn label(&self) -> &str {
        &self.label
    }

    fn disabled(&self) -> bool {
        self.on_open_menu.is_none()
    }

    fn activate(&mut self, hover: bool) -> Option<Self::Message> {
        if hover {
            Some(Action::OpenMenu.into())
        } else {
            None
        }
    }

    fn submit(&self) -> Option<Self::Message> {
        if self.disabled() {
            None
        } else {
            Some(Action::OpenMenu.into())
        }
    }

    fn open_menu(&self) -> Option<Self::Menu> {
        let open_menu = self.on_open_menu.as_ref()?;

        open_menu()
    }

    fn view(
        &self,
        active: bool,
        style: &Style,
    ) -> Option<snowcap_api::widget::WidgetDef<Self::Message>> {
        default_menu_view(self, active, style)
    }
}

#[derive(Debug, Clone)]
pub struct Separator<Msg>(PhantomData<Msg>);

impl<Msg> Separator<Msg> {
    pub fn new() -> Self {
        Self(PhantomData)
    }
}

impl<Msg> Default for Separator<Msg> {
    fn default() -> Self {
        Self::new()
    }
}

impl<Msg> TryWithEmitter for Separator<Msg> {
    fn try_with_emitter(&self) -> Option<crate::signal::Emitter> {
        None
    }
}

impl<Msg> Entry for Separator<Msg>
where
    Msg: Clone,
{
    type Menu = Menu<Msg>;
    type Message = MenuMessage<Msg>;

    fn key(&self) -> &str {
        "#glacier-entry-menu-separator"
    }

    fn set_key(&mut self, _key: String) {}

    fn label(&self) -> &str {
        ""
    }

    fn view(
        &self,
        _active: bool,
        style: &Style,
    ) -> Option<snowcap_api::widget::WidgetDef<Self::Message>> {
        let SeparatorStyle {
            fg_color,
            bg_color,
            height,
            padding,
            thickness,
        } = style.separator.clone().unwrap_or_default();

        let mut separator =
            Container::new(Column::new())
                .width(Length::Fill)
                .style(container::Style {
                    background: bg_color.map(From::from),
                    border: Some(Border {
                        color: fg_color,
                        width: thickness,
                        radius: None,
                    }),
                    ..Default::default()
                });

        separator.height = height;

        let mut container = Container::new(separator);
        container.padding = padding;

        Some(container.into())
    }
}
