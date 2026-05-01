use crate::{
    BlockOnTokio, color,
    menu::{self, entry::WithMenu},
    misc::icons,
    services::status_notifier as sni,
};

use menu::message::Message;
use snowcap_api::{
    signal::Signaler,
    widget::{self, Program, image, row, text},
};

pub type Menu = menu::Menu<Message>;
pub type Handle = menu::Handle<Message>;

enum Kind {
    Label,
    Radio(bool),
    Checkmark(bool),
}

struct Common {
    item_id: sni::item::UniqueId,
    node_id: i32,
    label: String,

    service: sni::StatusNotifier,
}

pub struct Entry {
    common: Common,
    kind: Kind,
}

pub struct SubMenu {
    common: Common,
    signaler: Signaler,
    config: menu::Config,
}

pub fn make_menu(
    sni_entries: &mut dyn Iterator<Item = (i32, &sni::menu::Properties)>,
    service: sni::StatusNotifier,
    item_id: &sni::item::UniqueId,
    config: &menu::Config,
) -> menu::Menu<Message> {
    let mut prev_is_sep = true;
    let mut menu = menu::Menu::new();

    for (node_id, props) in sni_entries {
        if !props.visible() {
            continue;
        } else if matches!(props.type_(), sni::menu::Type::Separator) {
            if !prev_is_sep {
                menu = menu.add_separator();
            }

            prev_is_sep = true;
            continue;
        }

        prev_is_sep = false;

        let mut entry = if props.children_display() == "submenu" {
            menu::Entry::menu(SubMenu::new(
                service.clone(),
                item_id,
                node_id,
                props,
                config.clone(),
            ))
        } else {
            menu::Entry::standard(Entry::new(service.clone(), item_id, node_id, props))
        };

        if !props.enabled() {
            entry = entry.disable();
        }

        menu = menu.add_entry(entry);
    }

    menu
}

impl Entry {
    pub fn new(
        service: sni::StatusNotifier,
        item_id: &sni::item::UniqueId,
        node_id: i32,
        props: &sni::menu::Properties,
    ) -> Self {
        let kind = match props.toggle_type() {
            sni::menu::ToggleType::None => Kind::Label,
            sni::menu::ToggleType::Radio => Kind::Radio(props.toggle_state().unwrap_or(false)),
            sni::menu::ToggleType::Checkmark => {
                Kind::Checkmark(props.toggle_state().unwrap_or(false))
            }
        };

        Self {
            common: Common::new(service, item_id, node_id, props),
            kind,
        }
    }
}

impl SubMenu {
    pub fn new(
        service: sni::StatusNotifier,
        item_id: &sni::item::UniqueId,
        node_id: i32,
        props: &sni::menu::Properties,
        config: menu::Config,
    ) -> Self {
        Self {
            common: Common::new(service, item_id, node_id, props),
            signaler: Signaler::new(),
            config,
        }
    }
}

impl Common {
    pub fn new(
        service: sni::StatusNotifier,
        item_id: &sni::item::UniqueId,
        node_id: i32,
        props: &sni::menu::Properties,
    ) -> Self {
        Self {
            item_id: item_id.to_owned(),
            node_id,
            label: props.label().to_owned(),

            service,
        }
    }

    pub fn view_label(&self) -> snowcap_api::widget::WidgetDef<Message> {
        let label = text::Text::new(&self.label).width(widget::Length::Fill);

        label.into()
    }

    pub fn click(&self) {
        self.service.click_menu(&self.item_id, self.node_id)
    }

    pub fn hover(&self) {
        self.service.hover_menu(&self.item_id, self.node_id)
    }
}

impl Program for Entry {
    type Message = Message;

    fn view(&self) -> Option<snowcap_api::widget::WidgetDef<Self::Message>> {
        let mut children = vec![self.common.view_label()];

        let toggle_icon = match self.kind {
            Kind::Checkmark(state) => Some(icons::checkmark::select(state)),
            Kind::Radio(state) => Some(icons::radio::select(state)),
            _ => None,
        };

        if let Some(toggle_icon) = toggle_icon {
            let handle = toggle_icon.to_image_handle(Some(color::from_hex("#ffffff")));

            let icon = image::Image::new(handle)
                .content_fit(image::ContentFit::ScaleDown)
                .height(widget::Length::Fixed(16.))
                .width(widget::Length::Fixed(16.));

            children.push(icon.into());
        }

        let row = row::Row::new_with_children(children);
        Some(row.into())
    }

    fn update(&mut self, msg: Self::Message) {
        use menu::entry::Message as EMessage;

        match msg {
            Message::Entry(EMessage::Hover) => {
                self.common.hover();
            }
            Message::Entry(EMessage::Submit) => {
                self.common.click();
            }
            _ => {}
        }
    }
}

impl Program for SubMenu {
    type Message = Message;

    fn view(&self) -> Option<widget::WidgetDef<Self::Message>> {
        Some(self.common.view_label())
    }

    fn signaler(&self) -> Option<Signaler> {
        Some(self.signaler.clone())
    }

    fn update(&mut self, msg: Self::Message) {
        use menu::entry::Message as EMessage;

        if let Message::Entry(EMessage::Hover) = msg {
            self.common.hover()
        }
    }
}

impl WithMenu for SubMenu {
    fn open_menu(&self) -> Option<menu::Menu<Self::Message>> {
        let service = &self.common.service;
        let item_id = &self.common.item_id;
        let node_id = self.common.node_id;

        let (tx, rx) = tokio::sync::oneshot::channel();

        service.open_menu(item_id, node_id, {
            let config = self.config.clone();
            let service = service.clone();
            let item_id = item_id.to_owned();

            move |iter| {
                let menu = make_menu(iter, service, &item_id, &config);

                if tx.send(menu).is_err() {
                    tracing::error!("Failed to send menu");
                }
            }
        });

        rx.block_on_tokio().ok()
    }
}
