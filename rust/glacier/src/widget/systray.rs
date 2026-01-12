//! System tray widget.
//!
//! [`SysTray`] allows to display system trays icons, which display a menu when clicked. When the
//! view function is called, this widgets renders each icons, wrap their view in a [`MouseArea`]
//! which handles the click and hover. This first render pass can be overridden through the
//! [`icon_view_callback`] attribute, and default to calling [`SysTray::default_icon_view`].
//!
//! The resulting views are then passed to another function, which should render the list itself.
//! This second pass can be overridden by via the [`view_callback`] attribute, and default to
//! calling [`SysTray::default_view`].
//!
//! When an icon is clicked, a menu is opened relative to its containing widget. The specific
//! config used is held by the [`menu_config`] attribute, which default to
//! [`SysTray::default_menu_config`]. This default config expect the [`SysTray`] to be on the
//! right-hand side of a bar, opening the menu down and to the left.
//!
//! [`icon_view_callback`]: SysTray::icon_view_callback
//! [`view_callback`]: SysTray::view_callback
//! [`menu_config`]: SysTray::menu_config

use futures::prelude::*;
use std::marker::PhantomData;

use snowcap_api::{
    popup::{self, Position},
    widget::{
        self, Length,
        container::{self, Container},
        image::{self, Image},
        mouse_area::MouseArea,
        row::Row,
    },
};

use crate::{
    menu::{Entry, Menu, MenuConfig, PopupConfig, signal as menu_signal},
    protocols::status_notifier,
    signal::{self, WithEmitter},
    widget::{
        State, WeakState, Widget, WidgetMessage, WithState,
        base::WidgetBase,
        message::{self, MessageBuilder},
        signal as widget_signal,
        systray::style::default_style,
    },
};

pub mod menu;
pub mod style;
#[doc(inline)]
pub use style::{IconStyle, Style};

pub type Message = message::Message<Action>;
pub type ViewCallback<Msg> = Box<
    dyn Fn(Vec<widget::WidgetDef<Msg>>, &Style) -> Option<widget::WidgetDef<Msg>> + Send + Sync,
>;
pub type IconViewCallback<Msg> =
    Box<dyn Fn(&status_notifier::Item, IconStyle) -> Option<widget::WidgetDef<Msg>> + Send + Sync>;

/// [`SysTray`] inner state
pub struct Inner<Msg> {
    base: WidgetBase,
    host: status_notifier::Host,
    hovered: Option<String>,
    active: Option<String>,
    menu_config: MenuConfig,
    menu: Option<Menu<()>>,
    menu_signal: Option<signal::Handle<menu_signal::Closed>>,
    style: Style,
    view_callback: Option<ViewCallback<Msg>>,
    icon_view_callback: Option<IconViewCallback<Msg>>,
    message_builder: MessageBuilder<Action>,
    _msg: PhantomData<Msg>,
}

/// [`SysTray`] actions.
#[derive(Clone, Debug)]
pub enum Action {
    Activate(String),
    Deactivate(String),
    Enter(String),
    Exit(String),
}

/// Systray widget.
///
/// See module level [documentation] for more information.
///
/// [documentation]: self
#[derive(Clone)]
pub struct SysTray<Msg> {
    state: State<Inner<Msg>>,
}

/// Non-owning [`SysTray`].
#[derive(Clone)]
pub struct WeakSysTray<Msg>(WeakState<Inner<Msg>>);

impl<Msg> SysTray<Msg>
where
    Msg: Clone + Send + Sync + 'static,
{
    const WIDGET_TYPE: &'static str = "SysTray";

    /// Create a new [`SysTray`]
    pub async fn new(connection: &zbus::Connection) -> Self {
        let base = WidgetBase::new(Self::WIDGET_TYPE);
        let message_builder = MessageBuilder::new(base.id());
        let host = status_notifier::Host::new(connection, format!("glacier-{}", base.id())).await;

        let mut host_stream = host.item_stream().await;

        let state = State::new(Inner {
            base,
            host,
            hovered: None,
            active: None,
            menu_config: Self::default_menu_config(),
            menu: None,
            menu_signal: None,
            style: default_style(),
            view_callback: None,
            icon_view_callback: None,
            message_builder,
            _msg: PhantomData,
        });

        tokio::spawn({
            let weak = WeakSysTray(state.downgrade());
            async move {
                while host_stream.next().await.is_some() {
                    let Some(systray) = weak.upgrade() else {
                        break;
                    };

                    systray.emit(crate::widget::signal::RedrawNeeded);
                }
            }
        });

        Self { state }
    }

    /// Sets the configuration to use when spawning menus.
    pub fn menu_config(self, config: MenuConfig) -> Self {
        self.state.0.lock().unwrap().menu_config = config;

        self
    }

    /// Sets the [`SysTray`]'s style.
    pub fn style(self, style: Style) -> Self {
        self.state.0.lock().unwrap().style = style;

        self
    }

    /// Sets a function to call when rendering the [`SysTray`].
    pub fn view_callback<F>(self, callback: F) -> Self
    where
        F: Fn(Vec<widget::WidgetDef<Msg>>, &Style) -> Option<widget::WidgetDef<Msg>>
            + Send
            + Sync
            + 'static,
    {
        self.state.0.lock().unwrap().view_callback = Some(Box::new(callback));
        self.emit(widget_signal::RedrawNeeded);

        self
    }

    /// Sets a function to call when rendering the [`SysTray`]'s icons.
    pub fn icon_view_callback<F>(self, callback: F) -> Self
    where
        F: Fn(&status_notifier::Item, IconStyle) -> Option<widget::WidgetDef<Msg>>
            + Send
            + Sync
            + 'static,
    {
        self.state.0.lock().unwrap().icon_view_callback = Some(Box::new(callback));
        self.emit(widget_signal::RedrawNeeded);

        self
    }

    /// Create a [`WeakSysTray`] pointing to the same state.
    pub fn downgrade(&self) -> WeakSysTray<Msg> {
        WeakSysTray(self.state.downgrade())
    }

    /// Default view to render SysTray.
    pub fn default_view(
        children: Vec<widget::WidgetDef<Msg>>,
        style: &Style,
    ) -> Option<widget::WidgetDef<Msg>> {
        let mut row = Row::new_with_children(children)
            .height(Length::Fill)
            .item_alignment(widget::Alignment::Center);

        row.spacing = style.spacing;

        let mut container = Container::new(row).style(container::Style {
            border: style.border,
            background_color: style.bg_color,
            ..Default::default()
        });

        container.padding = style.padding;

        Some(container.into())
    }

    /// Default view to render icons.
    pub fn default_icon_view(
        item: &status_notifier::Item,
        style: IconStyle,
    ) -> Option<widget::WidgetDef<Msg>> {
        let path = item
            .icon_theme_path()
            .zip(item.icon_name())
            .map(|(path, name)| format!("{path}/{name}.png"));

        let handle = if let Some(path) = path {
            image::Handle::Path(path.into())
        } else {
            let handle = item.with_pixmap(|pixmap| {
                let pixmap = pixmap.first()?;

                Some(widget::image::Handle::Rgba {
                    width: pixmap.width as u32,
                    height: pixmap.height as u32,
                    bytes: pixmap.bytes.clone(),
                })
            });

            handle.unwrap_or_else(|| {
                use crate::misc::color;
                use crate::misc::icons;

                icons::misc::broken_picture().to_image_handle(Some(color::from_hex("#FFFFFF")))
            })
        };

        let mut container = Container::new(Image::new(handle)).style(container::Style {
            border: style.border,
            background_color: style.bg_color,
            ..Default::default()
        });

        container.padding = style.padding;

        Some(container.into())
    }

    /// Default configuration used to create menus.
    pub fn default_menu_config() -> MenuConfig {
        MenuConfig {
            direction: Some(crate::menu::Direction::DownLeft),
            popup_config: Some(
                PopupConfig::new()
                    .anchor(popup::Anchor::BottomRight)
                    .offset(popup::Offset { x: 0., y: 8. }),
            ),
            child_popup_config: Some(PopupConfig::new().offset(popup::Offset { x: -2., y: 0. })),
            ..Default::default()
        }
    }
}

impl<Msg> WeakSysTray<Msg> {
    /// Tries to upgrade to a [`SysTray`], returning None if the value has already been destroyed.
    pub fn upgrade(&self) -> Option<SysTray<Msg>> {
        self.0.upgrade().map(|state| SysTray { state })
    }
}

impl<Msg> Inner<Msg>
where
    Msg: Clone + From<WidgetMessage> + Into<Option<WidgetMessage>> + Send + Sync + 'static,
{
    fn close_menu(&mut self) {
        let Some(menu) = self.menu.take() else {
            return;
        };

        if let Some(handle) = self.menu_signal.take() {
            menu.with_emitter().disconnect(handle);
        }

        menu.close();
    }

    fn view_icon(&self, item: &status_notifier::Item) -> Option<widget::WidgetDef<Msg>> {
        let key = item.name();
        let id = item.id();

        let style = self.style.get_icon_style(
            self.active.as_ref() == Some(&id),
            self.hovered.as_ref() == Some(&id),
        );
        let view = if let Some(callback) = &self.icon_view_callback {
            callback(item, style)?
        } else {
            SysTray::default_icon_view(item, style)?
        };

        let mouse_area = MouseArea::new(view)
            .on_release(self.message_builder.activate(key.clone()).into())
            .on_enter(self.message_builder.enter(key.clone()).into())
            .on_exit(self.message_builder.exit(key.clone()).into());

        Some(Container::new(mouse_area).id(id).into())
    }

    fn activate_item(&mut self, name: String, parent: Option<snowcap_api::popup::Parent>) {
        let config = self.menu_config.clone();
        let Some((root, id)) = self.host.with_items(|items| {
            items
                .iter()
                .find(|i| i.name() == name && i.is_menu())
                .and_then(|item| {
                    item.with_layout({
                        let id = item.id();
                        let weak = item.downgrade();
                        move |layout| {
                            let node = layout?;
                            Some((menu::Entry::new(weak, node, config.clone()), id))
                        }
                    })
                })
        }) else {
            return;
        };

        let Some(parent) = parent else {
            tracing::error!("Could not open menu: No parent handle");
            return;
        };

        if let Some(menu) = root.open_menu() {
            self.close_menu();

            let menu = menu.show(
                parent,
                None,
                Some(PopupConfig::new().position(Position::AtWidget(id.clone()))),
            );
            let handle = menu.with_emitter().connect({
                let deactivate = self.message_builder.deactivate(id.clone());
                let emitter = self.with_emitter();

                move |crate::menu::signal::Closed| {
                    emitter.emit(crate::widget::signal::Message::<Msg>(
                        deactivate.clone().into(),
                    ));
                    signal::HandlerPolicy::Discard
                }
            });

            self.menu = Some(menu);
            self.menu_signal = Some(handle);
            self.active = Some(id);
        }
    }

    fn deactivate_item(&mut self, name: String) {
        if self.active == Some(name) {
            self.menu_signal.take();
            self.menu.take();
        }
    }
}

impl MessageBuilder<Action> {
    fn activate(&self, key: String) -> WidgetMessage {
        self.build(Action::Activate(key))
    }

    fn deactivate(&self, key: String) -> WidgetMessage {
        self.build(Action::Deactivate(key))
    }

    fn enter(&self, key: String) -> WidgetMessage {
        self.build(Action::Enter(key))
    }

    fn exit(&self, key: String) -> WidgetMessage {
        self.build(Action::Exit(key))
    }
}

impl<Msg> WithEmitter for Inner<Msg> {
    fn with_emitter(&self) -> crate::signal::Emitter {
        self.base.with_emitter()
    }
}

impl<Msg> WithEmitter for SysTray<Msg> {
    fn with_emitter(&self) -> crate::signal::Emitter {
        self.state.0.lock().unwrap().with_emitter()
    }
}

impl<Msg> Widget for Inner<Msg>
where
    Msg: Clone + From<WidgetMessage> + Into<Option<WidgetMessage>> + Send + Sync + 'static,
{
    type Message = Msg;

    fn view(&self) -> Option<widget::WidgetDef<Self::Message>> {
        let children = self
            .host
            .with_items(|items| items.iter().flat_map(|item| self.view_icon(item)).collect());

        if let Some(callback) = &self.view_callback {
            callback(children, &self.style)
        } else {
            SysTray::default_view(children, &self.style)
        }
    }

    fn update(&mut self, msg: Self::Message, parent: Option<snowcap_api::popup::Parent>) {
        let Some(msg) = msg.into() else {
            return;
        };

        let action = match msg {
            WidgetMessage::SysTray(Message { id, action }) if id == self.base.id() => action,
            _ => return,
        };

        match action {
            Action::Enter(name) => {
                self.hovered = Some(name);
            }
            Action::Exit(name) => {
                if self.hovered == Some(name) {
                    self.hovered = None;
                }
            }
            Action::Activate(name) => self.activate_item(name, parent),
            Action::Deactivate(name) => self.deactivate_item(name),
        }
    }
}

impl<Msg> WithState for SysTray<Msg> {
    type Type = Inner<Msg>;

    fn with_state(&self) -> State<Self::Type> {
        self.state.clone()
    }
}

impl From<Message> for WidgetMessage {
    fn from(value: Message) -> Self {
        Self::SysTray(value)
    }
}
