//! System tray widget.
//!
//! [`SysTray`] allows running program to display System Tray icons & menus.

use snowcap_api::{
    popup,
    signal::{HandlerPolicy, Signaler},
    surface::SurfaceHandle,
    widget::{
        Alignment, Length, Padding, Program, WidgetDef,
        base::WidgetBase,
        container::{self, Container},
        image::{self, Image},
        message::UniversalMsg,
        mouse_area::MouseArea,
        row::Row,
        signal::Closed,
    },
};

use crate::{
    BlockOnTokio, color,
    misc::icons,
    services::status_notifier::{self, StatusNotifier, item},
    widget::message::{self, MessageBuilder},
};

pub mod style;
pub use style::Style;
pub mod menu;

pub type ViewCallback<Msg> =
    Box<dyn Fn(Vec<WidgetDef<Msg>>, &Style) -> Option<WidgetDef<Msg>> + Send>;

pub type ItemViewCallback<Msg> =
    Box<dyn Fn(&Item, style::IconStyle) -> Option<WidgetDef<Msg>> + Send>;

#[derive(Clone, Debug)]
enum Event {
    HoverStart(item::UniqueId),
    HoverStop(item::UniqueId),
    Activate(item::UniqueId),
    ToggleMenu(item::UniqueId),

    ItemAdded(Item),
    ItemUpdated(item::UniqueId, item::Update),
    ItemRemoved(item::UniqueId),

    //MenuOpened(item::UniqueId, menu::InFlightMenu),
    MenuReady(
        item::UniqueId,
        Vec<(i32, status_notifier::menu::Properties)>,
    ),
    MenuClosed(item::UniqueId),
}

type Message = message::Message<Event>;

/// System Tray Item.
#[derive(Clone, Debug)]
pub struct Item {
    /// Internal id used to uniquely identify the item.
    pub unique_id: item::UniqueId,

    /// Item id, as reported via D-Bus.
    pub id: String,
    /// Item icon handle.
    pub icon: Option<image::Handle>,
    /// Icon handle to use when the item request attention.
    pub attention_icon: Option<image::Handle>,
    /// Item [`Status`].
    ///
    /// [`Status`]: item::Status
    pub status: item::Status,

    /// If true, the item will always show a menu when activated.
    pub is_menu: bool,
}

struct OpenMenu {
    item_id: item::UniqueId,
    handle: menu::Handle,
    signaler: Signaler,
    close_sig: snowcap_api::signal::Handle<Closed>,
}

/// System Tray area.
///
/// See module level [documentation].
///
/// [documentation]: self
pub struct SysTray<Msg> {
    base: WidgetBase,
    builder: MessageBuilder<Event>,
    service: StatusNotifier,

    items: Vec<Item>,
    hovered: Option<item::UniqueId>,

    open_menu: Option<OpenMenu>,
    menu_config: crate::menu::Config,
    submenu_config: crate::menu::Config,

    style: Style,
    view_callback: Option<ViewCallback<Msg>>,
    item_view_callback: Option<ItemViewCallback<Msg>>,
    surface: Option<SurfaceHandle<Msg>>,
}

/// Default SysTray [`Style`].
pub fn default_style() -> Style {
    Style::new()
        .spacing(1.)
        .icon_padding(Padding {
            top: 2.,
            right: 2.,
            bottom: 2.,
            left: 2.,
        })
        .hovered(style::IconStyle {
            bg_color: Some(color::from_hex("#575757")),
            ..Default::default()
        })
        .active(style::IconStyle {
            bg_color: Some(color::from_hex("#474747")),
            ..Default::default()
        })
}

/// Default config for `Item`'s primary [`Menu`].
///
/// [`Menu`]: crate::menu::Menu
pub fn default_menu_config() -> crate::menu::Config {
    crate::menu::Config::new()
        .anchor(popup::Anchor::BottomRight)
        .gravity(popup::Gravity::BottomLeft)
        .offset(popup::Offset { x: 0., y: 8. })
}

/// Default config for `Item`'s secondary [`Menu`].
///
/// [`Menu`]: crate::menu::Menu
pub fn default_submenu_config() -> crate::menu::Config {
    default_menu_config()
        .anchor(popup::Anchor::TopLeft)
        .offset(popup::Offset { x: -2., y: 0. })
}

impl<Msg> SysTray<Msg> {
    /// Default view for [`SysTray`].
    ///
    /// This function is called when no [`ViewCallback`] has been set. It renders as a simple
    /// row of items.
    pub fn default_view(children: Vec<WidgetDef<Msg>>, style: &Style) -> Option<WidgetDef<Msg>> {
        let mut row = Row::new_with_children(children)
            .height(Length::Fill)
            .item_alignment(Alignment::Center);

        row.spacing = style.spacing;

        let mut container = Container::new(row).style(container::Style {
            border: style.border,
            background: style.bg_color.map(From::from),
            ..Default::default()
        });

        container.padding = style.padding;

        Some(container.into())
    }

    /// Default view for SysTray's [`Item`]s.
    ///
    /// This function is called when no [`ItemViewCallback`] has been set. It renders items using
    /// their icon, or attention icons if needed.
    pub fn default_item_view(item: &Item, style: style::IconStyle) -> Option<WidgetDef<Msg>> {
        let icon = item.icon.as_ref();
        let attention_icon = item.attention_icon.as_ref();

        let handle = if matches!(item.status, item::Status::NeedsAttention)
            && let Some(handle) = attention_icon
        {
            handle.clone()
        } else if let Some(handle) = icon {
            handle.clone()
        } else {
            icons::misc::broken_picture().to_image_handle(Some(color::from_hex("#FFFFFF")))
        };

        let mut container = Container::new(Image::new(handle)).style(container::Style {
            border: style.border,
            background: style.bg_color.map(From::from),
            ..Default::default()
        });

        container.padding = style.padding;

        Some(container.into())
    }
}

impl<Msg> SysTray<Msg> {
    const PROGRAM_NAME: &'static str = "SysTray";

    /// Build a new [`SysTray`] widget.
    pub fn new(service: StatusNotifier) -> Self {
        let base = WidgetBase::new(Self::PROGRAM_NAME);
        let builder = MessageBuilder::new(base.id());

        Self {
            base,
            builder,
            service,

            items: Vec::new(),
            open_menu: None,
            hovered: None,

            menu_config: default_menu_config(),
            submenu_config: default_submenu_config(),

            style: default_style(),
            view_callback: None,
            item_view_callback: None,

            surface: None,
        }
    }

    /// Sets the [`SysTray`] style.
    pub fn style(self, style: Style) -> Self {
        Self { style, ..self }
    }

    /// Sets the [`SysTray`] view callback.
    pub fn view_callback<F>(self, callback: F) -> Self
    where
        F: Fn(Vec<WidgetDef<Msg>>, &Style) -> Option<WidgetDef<Msg>> + Send + 'static,
    {
        Self {
            view_callback: Some(Box::new(callback)),
            ..self
        }
    }

    /// Sets the [`SysTray`] item view callback.
    pub fn item_view_callback<F>(self, callback: F) -> Self
    where
        F: Fn(&Item, style::IconStyle) -> Option<WidgetDef<Msg>> + Send + 'static,
    {
        Self {
            item_view_callback: Some(Box::new(callback)),
            ..self
        }
    }
}

impl<Msg> SysTray<Msg>
where
    Msg: From<UniversalMsg> + Clone + Send + 'static,
{
    fn get_initial_state(&mut self) {
        self.items = self
            .service
            .with_items(|items| items.map(Item::from).collect())
            .block_on_tokio();
    }

    fn connect_service_signals(&mut self) {
        use snowcap_api::widget::signal::Message;
        use status_notifier::signal;

        let signaler = self.base.signaler();

        self.service.connect({
            let weak = signaler.downgrade();
            let builder = self.builder;
            move |signal::ItemAdded(state)| {
                let Some(signaler) = weak.upgrade() else {
                    return HandlerPolicy::Discard;
                };

                signaler.emit(Message::<Msg>(builder.item_added(state).into()));

                HandlerPolicy::Keep
            }
        });

        self.service.connect({
            let weak = signaler.downgrade();
            let builder = self.builder;
            move |signal::ItemUpdated(item_id, update)| {
                let Some(signaler) = weak.upgrade() else {
                    return HandlerPolicy::Discard;
                };

                signaler.emit(Message::<Msg>(builder.item_updated(item_id, update).into()));
                HandlerPolicy::Keep
            }
        });

        self.service.connect({
            let weak = signaler.downgrade();
            let builder = self.builder;
            move |signal::ItemRemoved(item_id)| {
                let Some(signaler) = weak.upgrade() else {
                    return HandlerPolicy::Discard;
                };

                signaler.emit(Message::<Msg>(builder.item_removed(item_id).into()));
                HandlerPolicy::Keep
            }
        });
    }

    fn update_item(&mut self, item_id: item::UniqueId, update: item::Update) {
        use item::Update;

        let Some(item) = self.items.iter_mut().find(|i| i.unique_id == item_id) else {
            return;
        };

        match update {
            Update::Icon(handle) => item.icon = Some(handle),
            Update::AttentionIcon(handle) => item.attention_icon = Some(handle),
            Update::Status(status) => item.status = status,
            _ => {}
        };
    }

    fn view_item(&self, item: &Item) -> Option<WidgetDef<Msg>> {
        let uid = &item.unique_id;
        let style = self.style.get_icon_style(
            self.open_menu.as_ref().map(|om| &om.item_id) == Some(uid),
            self.hovered.as_ref() == Some(uid),
        );

        let view = if let Some(callback) = self.item_view_callback.as_ref() {
            callback(item, style)?
        } else {
            SysTray::default_item_view(item, style)?
        };

        let builder = self.builder;
        let mouse_area = MouseArea::new(view)
            .on_enter(builder.hover_start(uid.clone()).into())
            .on_exit(builder.hover_stop(uid.clone()).into())
            .on_release(builder.activate(uid.clone()).into())
            .on_right_release(builder.toggle_menu(uid.clone()).into());

        Some(
            Container::new(mouse_area)
                .id(uid.clone().into_inner())
                .into(),
        )
    }

    fn close_menu(&mut self) {
        let Some(OpenMenu {
            item_id: _,
            handle,
            signaler,
            close_sig,
        }) = self.open_menu.take()
        else {
            return;
        };

        signaler.disconnect(close_sig);
        drop(signaler);

        handle.close();
    }

    fn open_menu(&mut self, item_id: item::UniqueId, menu: menu::Menu) {
        self.close_menu();

        let Some(surface) = self.surface.as_ref() else {
            return;
        };

        if self.find_item(&item_id).is_none() {
            return;
        }

        let close_sig = menu.connect({
            let weak = self.base.signaler().downgrade();
            let builder = self.builder;
            let item_id = item_id.clone();
            move |snowcap_api::widget::signal::Closed| {
                let Some(signaler) = weak.upgrade() else {
                    return HandlerPolicy::Discard;
                };

                signaler.emit(snowcap_api::widget::signal::Message::<Msg>(
                    builder.menu_closed(item_id.clone()).into(),
                ));
                HandlerPolicy::Discard
            }
        });

        let signaler = menu.signaler().unwrap();

        self.open_menu = menu
            .submenu_config(self.submenu_config.clone())
            .popup(
                surface,
                popup::Position::at_widget(item_id.clone().into_inner()),
                self.menu_config.clone(),
            )
            .map(move |handle| OpenMenu {
                item_id,
                handle,
                signaler,
                close_sig,
            });
    }

    fn find_item(&self, uid: &item::UniqueId) -> Option<&Item> {
        self.items.iter().find(|i| &i.unique_id == uid)
    }

    fn activate_impl(&self, item: &Item) {
        self.service.activate_item(&item.unique_id);
    }

    fn activate(&mut self, id: item::UniqueId) {
        self.close_menu();
        let Some(item) = self.find_item(&id) else {
            return;
        };

        if item.is_menu {
            self.toggle_menu_impl(item);
        } else {
            self.activate_impl(item);
        }
    }

    fn toggle_menu_impl(&self, item: &Item) {
        self.service.open_menu(&item.unique_id, 0, {
            let item_id = item.unique_id.clone();
            let builder = self.builder;
            let signaler = self.base.signaler();

            move |iter| {
                let menu_template: Vec<_> =
                    iter.map(|(id, props)| (id, props.to_owned())).collect();

                signaler.emit(snowcap_api::widget::signal::Message::<Msg>(
                    builder.menu_ready(item_id, menu_template).into(),
                ));
            }
        });
    }

    fn toggle_menu(&mut self, uid: &item::UniqueId) {
        self.close_menu();

        let Some(item) = self.find_item(uid) else {
            return;
        };

        self.toggle_menu_impl(item);
    }
}

impl<Msg> Program for SysTray<Msg>
where
    Msg: From<UniversalMsg> + TryInto<UniversalMsg> + Clone + Send + 'static,
{
    type Message = Msg;

    fn view(&self) -> Option<snowcap_api::widget::WidgetDef<Self::Message>> {
        let children = self
            .items
            .iter()
            .flat_map(|item| self.view_item(item))
            .collect();

        if let Some(view_callback) = self.view_callback.as_ref() {
            view_callback(children, &self.style)
        } else {
            Self::default_view(children, &self.style)
        }
    }

    fn event(&mut self, event: snowcap_api::surface::SurfaceEvent<Self::Message>) {
        if let snowcap_api::surface::SurfaceEvent::Created { surface } = event {
            self.get_initial_state();
            self.connect_service_signals();
            self.surface = Some(surface);
        }
    }

    fn update(&mut self, msg: Self::Message) {
        let Some(universal) = msg.try_into().ok() else {
            return;
        };

        let event = match universal.downcast::<Message>() {
            Ok(message::Message { id, event }) if id == self.base.id() => event,
            _ => return,
        };

        match event {
            Event::HoverStart(id) => self.hovered = Some(id),
            Event::HoverStop(id) => {
                if self.hovered == Some(id) {
                    self.hovered.take();
                }
            }
            Event::Activate(id) => self.activate(id),
            Event::ToggleMenu(id) => self.toggle_menu(&id),

            Event::ItemAdded(item) => self.items.push(item),
            Event::ItemUpdated(id, update) => self.update_item(id, update),
            Event::ItemRemoved(item_id) => self.items.retain(|i| i.unique_id != item_id),

            Event::MenuReady(item_id, template) => {
                let menu = menu::make_menu(
                    &mut template.iter().map(|(id, prop)| (*id, prop)),
                    self.service.clone(),
                    &item_id,
                    &self.menu_config,
                );

                self.open_menu(item_id, menu);
            }
            Event::MenuClosed(item_id) => {
                self.open_menu.take_if(|m| m.item_id == item_id);
            }
        }
    }

    fn signaler(&self) -> Option<snowcap_api::signal::Signaler> {
        Some(self.base.signaler())
    }
}

impl MessageBuilder<Event> {
    fn hover_start(&self, id: item::UniqueId) -> UniversalMsg {
        self.build(Event::HoverStart(id))
    }

    fn hover_stop(&self, id: item::UniqueId) -> UniversalMsg {
        self.build(Event::HoverStop(id))
    }

    fn activate(&self, id: item::UniqueId) -> UniversalMsg {
        self.build(Event::Activate(id))
    }

    fn toggle_menu(&self, id: item::UniqueId) -> UniversalMsg {
        self.build(Event::ToggleMenu(id))
    }

    fn item_added(&self, item: impl Into<Item>) -> UniversalMsg {
        self.build(Event::ItemAdded(item.into()))
    }

    fn item_updated(&self, item_id: item::UniqueId, update: item::Update) -> UniversalMsg {
        self.build(Event::ItemUpdated(item_id, update))
    }

    fn item_removed(&self, item_id: item::UniqueId) -> UniversalMsg {
        self.build(Event::ItemRemoved(item_id))
    }

    fn menu_ready(
        &self,
        item_id: item::UniqueId,
        menu_template: Vec<(i32, status_notifier::menu::Properties)>,
    ) -> UniversalMsg {
        self.build(Event::MenuReady(item_id, menu_template))
    }

    fn menu_closed(&self, item_id: item::UniqueId) -> UniversalMsg {
        self.build(Event::MenuClosed(item_id))
    }
}

impl From<&item::Item> for Item {
    fn from(item: &item::Item) -> Self {
        item.state().clone().into()
    }
}

impl From<item::State> for Item {
    fn from(state: item::State) -> Self {
        Self {
            unique_id: state.unique_id,
            id: state.id,
            icon: state.icon,
            attention_icon: state.attention_icon,
            status: state.status,
            is_menu: state.is_menu,
        }
    }
}
