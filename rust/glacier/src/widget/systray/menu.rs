//! [`SysTray`]'s menu.
//!
//! [`SysTray`]: super
use snowcap_api::widget::{self, container, image, row, text};

use crate::{
    menu::{
        self, Action, Menu, MenuConfig, MenuMessage,
        entry::{EntryState, style::EntryStyle},
    },
    misc::{icons, image::AlphaMask},
    protocols::status_notifier::{
        item::WeakItem,
        layout::{self, Node},
    },
    signal::TryWithEmitter,
};

/// Entry in a [`SysTray`]'s menu.
///
/// This type bridges [`Menu`] and DBusMenu Protocol, by wrapping a [`Node`] in a type implementing
/// [`menu::Entry`].
///
/// [`SysTray`]: super
pub struct Entry {
    key: String,
    item: WeakItem,
    node: Node,
    menu: Option<Menu<()>>,
}

impl Entry {
    /// Create a new [`Entry`]
    pub fn new(item: WeakItem, node: &Node, menu_config: MenuConfig) -> Self {
        let Node {
            id,
            props,
            children,
        } = node;

        let menu = if node.is_submenu() {
            Some(Self::make_menu(item.clone(), children, menu_config))
        } else {
            None
        };

        let node = Node {
            id: *id,
            props: props.clone(),
            children: Default::default(),
        };

        Self {
            key: Default::default(),
            item,
            node,
            menu,
        }
    }

    fn make_menu(item: WeakItem, children: &Vec<Node>, menu_config: MenuConfig) -> Menu<()> {
        let mut entries: Vec<menu::BoxedEntry<()>> = Vec::default();
        let mut prev_is_sep = true;

        for node in children {
            if !node.is_visible() {
                continue;
            }

            match node.type_() {
                layout::Type::Separator if prev_is_sep => {
                    continue;
                }
                layout::Type::Separator => {
                    entries.push(Box::new(menu::entry::Separator::new()));
                }
                layout::Type::Standard => {
                    entries.push(Box::new(Self::new(item.clone(), node, menu_config.clone())));
                }
                layout::Type::Vendor(vendor, type_) => {
                    tracing::warn!("Unknown type x-{vendor}-{type_}. Using standard type instead.");
                    entries.push(Box::new(Self::new(item.clone(), node, menu_config.clone())));
                }
            }

            prev_is_sep = matches!(node.type_(), layout::Type::Separator);
        }

        Menu::with_config(menu_config).entries(entries)
    }

    fn view_toggle(
        &self,
        active: bool,
        style: &menu::entry::Style,
        icon_mask: AlphaMask,
    ) -> Option<snowcap_api::widget::WidgetDef<MenuMessage<()>>> {
        let EntryStyle {
            fg_color,
            bg_color,
            height,
            padding,
            border,
        } = EntryState::from_entry(self, active).get_entry_style(style);

        let label_widget = text::Text::new(self.node.label())
            .width(widget::Length::Fill)
            .style(text::Style {
                color: fg_color,
                font: style.font.clone(),
                pixels: style.font_size,
            });

        let icon_handle = icon_mask.to_image_handle(
            style
                .menu_indicator
                .as_ref()
                .and_then(|i| i.color)
                .or(fg_color),
        );
        let icon = image::Image::new(icon_handle)
            .content_fit(image::ContentFit::ScaleDown)
            .height(widget::Length::Fixed(16.))
            .width(widget::Length::Fixed(16.));

        let mut container = container::Container::new(
            row::Row::new_with_children([label_widget.into(), icon.into()])
                .item_alignment(widget::Alignment::Center),
        )
        .clip(true)
        .width(widget::Length::Fill)
        .vertical_alignment(widget::Alignment::Center)
        .style(container::Style {
            background: bg_color.map(From::from),
            border,
            ..Default::default()
        });

        container.padding = padding;
        container.height = height;

        Some(container.into())
    }
}

impl menu::Entry for Entry {
    type Message = MenuMessage<()>;
    type Menu = Menu<()>;

    fn key(&self) -> &str {
        self.key.as_str()
    }

    fn set_key(&mut self, key: String) {
        self.key = key;
    }

    fn label(&self) -> &str {
        self.node.label()
    }

    fn disabled(&self) -> bool {
        !self.node.is_enabled()
    }

    fn activate(&mut self, hover: bool) -> Option<Self::Message> {
        self.item.upgrade()?.hover(self.node.id());

        if hover && self.node.is_submenu() {
            Some(Action::OpenMenu.into())
        } else {
            None
        }
    }

    fn submit(&self) -> Option<Self::Message> {
        if self.node.is_submenu() {
            Some(Action::OpenMenu.into())
        } else if let Some(item) = self.item.upgrade() {
            item.click(self.node.id());
            Some(Action::Close.into())
        } else {
            None
        }
    }

    fn open_menu(&self) -> Option<Self::Menu> {
        if !self.node.is_submenu() {
            return None;
        }

        self.menu.clone()
    }

    fn view(
        &self,
        active: bool,
        style: &menu::entry::Style,
    ) -> Option<snowcap_api::widget::WidgetDef<Self::Message>> {
        match (self.node.is_submenu(), self.node.toggle_type()) {
            (true, _) => menu::entry::default_menu_view(self, active, style),
            (_, layout::ToggleType::Radio) => {
                self.view_toggle(active, style, icons::radio::select(self.node.is_toggled()))
            }
            (_, layout::ToggleType::Checkmark) => self.view_toggle(
                active,
                style,
                icons::checkmark::select(self.node.is_toggled()),
            ),
            (_, layout::ToggleType::None) => menu::entry::default_entry_view(self, active, style),
        }
    }
}

impl TryWithEmitter for Entry {}
