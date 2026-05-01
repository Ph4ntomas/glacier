use futures::prelude::*;
use snowcap_api::widget::image;

use crate::protocols::status_notifier::{self as sni, item_proxy::ItemProxy};

use super::menu;

pub use sni::item::Status;

#[derive(Clone, Debug)]
pub enum Update {
    Title(String),
    Status(sni::item::Status),

    Icon(image::Handle),
    AttentionIcon(image::Handle),
    OverlayIcon(image::Handle),

    Menu,
}

/// An object that uniquely identify an [`Item`].
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct UniqueId(String);

/// [`Item`] public state.
#[derive(Clone, Debug)]
pub struct State {
    /// An object that uniquely identifies this item.
    pub unique_id: UniqueId,
    pub id: String,

    pub title: Option<String>,
    pub status: Status,

    pub icon: Option<image::Handle>,
    pub attention_icon: Option<image::Handle>,
    pub overlay_icon: Option<image::Handle>,

    pub is_menu: bool,
}

/// StatusNotifierItem representation.
pub struct Item {
    state: State,
    menu: Option<menu::Menu>,

    remote: sni::Item,
    abort_handle: Option<stream::AbortHandle>,
}

impl UniqueId {
    pub fn into_inner(self) -> String {
        self.0
    }
}

impl Item {
    /// Create a new [`Item`].
    pub async fn new(connection: &zbus::Connection, remote: sni::Item) -> zbus::Result<Self> {
        let proxy = remote.proxy();

        let id = proxy.id().await?;
        let title = proxy.title().await.ok();
        let status = proxy.status().await.map(From::from)?;

        let icon = Update::icon(&remote).await.map(|update| {
            let Update::Icon(handle) = update else {
                unreachable!()
            };
            handle
        });

        let attention_icon = Update::attention_icon(&remote).await.map(|update| {
            let Update::AttentionIcon(handle) = update else {
                unreachable!()
            };
            handle
        });

        let overlay_icon = Update::overlay_icon(&remote).await.map(|update| {
            let Update::OverlayIcon(handle) = update else {
                unreachable!()
            };
            handle
        });

        let is_menu = proxy.item_is_menu().await.unwrap_or(false);

        let menu = Self::new_menu(&remote, connection).await;

        Ok(Self {
            state: State {
                unique_id: remote.bus_id().into(),
                id,

                title,
                status,

                icon,
                attention_icon,
                overlay_icon,

                is_menu,
            },
            menu,

            remote,
            abort_handle: None,
        })
    }

    /// The [`Item`] id, as received from DBus.
    ///
    /// Because several StatusNotifierItem may have the same `Id` due to their use of framework, this
    /// value cannot be used reliably to disambiguate between two item, and [`Item::bus_id`]
    /// should be preferred for that use-case.
    pub fn id(&self) -> &str {
        &self.state.id
    }

    pub fn unique_id(&self) -> &UniqueId {
        &self.state.unique_id
    }

    /// The [`Item`] status.
    pub fn status(&self) -> Status {
        self.state.status
    }

    /// An [`image::Handle`] that can be displayed to represent the [`Item`].
    pub fn icon(&self) -> Option<&image::Handle> {
        self.state.icon.as_ref()
    }

    /// An [`image::Handle`] that may be displayed when the [`Item`] requires user attention.
    pub fn attention_icon(&self) -> Option<&image::Handle> {
        self.state.attention_icon.as_ref()
    }

    /// [`Item`] public state.
    pub fn state(&self) -> &State {
        &self.state
    }

    /// Whether the [`Item`] is a menu.
    ///
    /// If this returns true, the associated menu should be displayed on user interaction, instead
    /// of calling [`Item::activate`].
    pub fn is_menu(&self) -> bool {
        self.state.is_menu
    }

    /// Access the [`Menu`] associated with this [`Item`].
    ///
    /// [`Menu`]: menu::Menu
    pub fn menu(&self) -> Option<&menu::Menu> {
        self.menu.as_ref()
    }

    /// Get mutable access the [`Menu`] associated with this [`Item`].
    ///
    /// [`Menu`]: menu::Menu
    pub fn menu_mut(&mut self) -> Option<&mut menu::Menu> {
        self.menu.as_mut()
    }

    /// [`Item`] unique representation on DBus.
    pub fn bus_id(&self) -> &str {
        self.remote.bus_id()
    }

    /// Access the underlying DBus proxy.
    pub fn proxy(&self) -> &ItemProxy<'static> {
        self.remote.proxy()
    }

    /// Access the underlying [`sni::Item`].
    pub fn remote(&self) -> &sni::Item {
        &self.remote
    }

    /// Activate this [`Item`].
    ///
    /// This function should be called after a primary interaction (i.e. left-click) on the item
    /// graphical representation. The actual behavior after calling this function is defined by the
    /// remote client.
    pub async fn activate(&self) {
        if let Err(e) = self.proxy().activate(0, 0).await {
            tracing::warn!("While activating {}: {}", self.id(), e);
        };
    }

    /// Get this [`Item`] update as a [`stream::BoxStream`].
    pub async fn update_stream(&mut self) -> stream::BoxStream<'static, (UniqueId, Update)> {
        let stream = self
            .remote
            .signal_stream()
            .await
            .then({
                let remote = self.remote.clone();
                move |sig| Self::signal_to_update(sig, remote.clone())
            })
            .filter_map({
                let uid = self.unique_id().to_owned();
                move |update| future::ready(update.map(|u| (uid.clone(), u)))
            });

        let (stream, handle) = stream::abortable(stream);
        self.abort_handle = Some(handle);
        stream.boxed()
    }

    /// Update the [`Item`] state.
    pub fn apply_update(&mut self, update: Update) {
        match update {
            Update::Title(title) => self.state.title = Some(title),
            Update::Status(status) => self.state.status = status,

            Update::Icon(handle) => self.state.icon = Some(handle),
            Update::AttentionIcon(handle) => self.state.attention_icon = Some(handle),
            Update::OverlayIcon(handle) => self.state.overlay_icon = Some(handle),

            Update::Menu => {}
        }
    }

    async fn new_menu(remote: &sni::Item, connection: &zbus::Connection) -> Option<menu::Menu> {
        let remote_menu = remote.menu(connection).await?;

        menu::Menu::new(remote_menu).await.ok()
    }

    /// Refresh the item's [`Menu`].
    ///
    /// This function should be called as a result of an [`Update::Menu`].
    ///
    /// [`Menu`]: menu::Menu
    pub async fn refresh_menu(&mut self, connection: &zbus::Connection) {
        self.menu = Self::new_menu(self.remote(), connection).await;
    }

    async fn signal_to_update(signal: sni::item::Signal, remote: sni::Item) -> Option<Update> {
        use sni::item::Signal;

        match signal {
            Signal::NewTitle => Update::title(&remote).await,
            Signal::NewStatus(status) => Update::status(status).await,
            Signal::NewIcon => Update::icon(&remote).await,
            Signal::NewAttentionIcon => Update::attention_icon(&remote).await,
            Signal::NewOverlayIcon => Update::overlay_icon(&remote).await,
            Signal::NewMenu => Some(Update::Menu),
            _ => None,
        }
    }
}

impl Update {
    async fn icon(remote: &sni::Item) -> Option<Self> {
        let proxy = remote.proxy();
        let icon_path = proxy
            .icon_theme_path()
            .await
            .ok()
            .filter(|path| !path.is_empty());
        let name = proxy.icon_name().await.ok().filter(|name| !name.is_empty());

        let path = icon_path
            .zip(name)
            .map(|(path, name)| format!("{path}/{name}.png"));

        let handle = if let Some(path) = path {
            Some(image::Handle::Path(path.into()))
        } else if let Ok(pixmaps) = proxy.icon_pixmap().await {
            pixmaps.into_iter().next().map(image::Handle::from)
        } else {
            None
        };

        handle.map(Self::Icon)
    }

    async fn attention_icon(remote: &sni::Item) -> Option<Self> {
        let proxy = remote.proxy();
        let icon_path = proxy
            .icon_theme_path()
            .await
            .ok()
            .filter(|path| !path.is_empty());
        let name = proxy
            .attention_icon_name()
            .await
            .ok()
            .filter(|name| !name.is_empty());

        let path = icon_path
            .zip(name)
            .map(|(path, name)| format!("{path}/{name}.png"));

        let handle = if let Some(path) = path {
            Some(image::Handle::Path(path.into()))
        } else if let Ok(pixmaps) = proxy.attention_icon_pixmap().await {
            pixmaps.into_iter().next().map(image::Handle::from)
        } else {
            None
        };

        handle.map(Self::AttentionIcon)
    }

    async fn overlay_icon(remote: &sni::Item) -> Option<Self> {
        let proxy = remote.proxy();

        let icon_path = proxy
            .icon_theme_path()
            .await
            .ok()
            .filter(|path| !path.is_empty());
        let name = proxy
            .overlay_icon_name()
            .await
            .ok()
            .filter(|name| !name.is_empty());

        let path = icon_path
            .zip(name)
            .map(|(path, name)| format!("{path}/{name}.png"));

        let handle = if let Some(path) = path {
            Some(image::Handle::Path(path.into()))
        } else if let Ok(pixmaps) = proxy.overlay_icon_pixmap().await {
            pixmaps.into_iter().next().map(image::Handle::from)
        } else {
            None
        };

        handle.map(Update::OverlayIcon)
    }

    async fn title(remote: &sni::Item) -> Option<Self> {
        remote.proxy().title().await.ok().map(Update::Title)
    }

    async fn status(status: sni::item::Status) -> Option<Self> {
        Some(Update::Status(status))
    }
}

impl From<&str> for UniqueId {
    fn from(value: &str) -> Self {
        Self(value.to_owned())
    }
}

impl From<String> for UniqueId {
    fn from(value: String) -> Self {
        Self(value)
    }
}

impl From<UniqueId> for String {
    fn from(value: UniqueId) -> Self {
        value.0
    }
}

impl Drop for Item {
    fn drop(&mut self) {
        if let Some(handle) = self.abort_handle.as_ref() {
            handle.abort();
        }
    }
}
