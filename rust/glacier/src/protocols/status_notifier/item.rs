//! StatusNotifierItems implementation.
//!
//! [`Item`] represents StatusNotifierItems and their associated DBusMenu.
use std::sync::{Arc, Mutex, Weak};

use futures::StreamExt;

use crate::{
    BlockOnTokio,
    protocols::status_notifier::{
        dbusmenu_proxy::DBusMenuProxy, item_proxy::ItemProxy, layout::Node,
    },
};

struct Inner {
    item_proxy: ItemProxy<'static>,
    menu_proxy: Option<DBusMenuProxy<'static>>,
    id: String,
    title: Option<String>,
    icon_name: Option<String>,
    icon_theme_path: Option<String>,
    layout: Option<Node>,
    layout_rev: Option<u32>,
    name: String,
}

/// Item implementation.
#[derive(Clone)]
pub struct Item {
    state: Arc<Mutex<Inner>>,
}

/// Non-owning [`Item`].
#[derive(Clone)]
pub struct WeakItem(Weak<Mutex<Inner>>);

impl Item {
    /// Create a new [`Item`].
    ///
    /// This function is usually called by a StatusNotifierHost.
    pub async fn new(connection: &zbus::Connection, name: String) -> zbus::Result<Self> {
        let (destination, path) = if let Some(idx) = name.find('/') {
            (&name[..idx], &name[idx..])
        } else {
            (name.as_str(), "/StatusNotifierItem")
        };

        let item_proxy = ItemProxy::builder(connection)
            .cache_properties(zbus::proxy::CacheProperties::No)
            .destination(destination.to_string())?
            .path(path.to_string())?
            .build()
            .await?;

        let id = item_proxy.id().await.unwrap();
        let title = item_proxy.title().await.ok().filter(|s| !s.is_empty());
        let icon_name = item_proxy.icon_name().await.ok().filter(|s| !s.is_empty());
        let icon_theme_path = item_proxy
            .icon_theme_path()
            .await
            .ok()
            .filter(|s| !s.is_empty());

        let is_menu = item_proxy.item_is_menu().await;
        let menu_path = item_proxy.menu().await;

        let is_menu = menu_path.is_ok() || is_menu.unwrap_or(false);

        if !is_menu {
            return Ok(Self {
                state: Arc::new(Mutex::new(Inner {
                    item_proxy,
                    menu_proxy: None,
                    id,
                    title,
                    icon_name,
                    icon_theme_path,
                    layout: None,
                    layout_rev: None,
                    name,
                })),
            });
        };

        let menu_path = menu_path?;
        let menu_proxy = DBusMenuProxy::builder(connection)
            .destination(destination.to_string())?
            .path(menu_path)?
            .build()
            .await?;

        let (rev, layout) = menu_proxy
            .get_layout(0, -1, &[])
            .await
            .expect("Could not get initial layout.");

        let mut layout_stream = menu_proxy.receive_layout_updated().await.unwrap();

        let state = Arc::new(Mutex::new(Inner {
            item_proxy,
            menu_proxy: Some(menu_proxy),
            id,
            title,
            icon_name,
            icon_theme_path,
            layout: Some(layout),
            layout_rev: Some(rev),
            name,
        }));

        tokio::spawn({
            let weak = WeakItem(Arc::downgrade(&state));
            async move {
                while layout_stream.next().await.is_some() {
                    let Some(item) = weak.upgrade() else {
                        break;
                    };

                    item.refresh_layout_async().await;
                }
            }
        });

        Ok(Self { state })
    }

    /// Gets the item id.
    pub fn id(&self) -> String {
        self.state.lock().unwrap().id.clone()
    }

    /// Check if an item is a menu.
    pub fn is_menu(&self) -> bool {
        self.state.lock().unwrap().menu_proxy.is_some()
    }

    /// Gets the Item's title.
    pub fn title(&self) -> Option<String> {
        self.state.lock().unwrap().title.clone()
    }

    /// Gets the Item's icon name.
    pub fn icon_name(&self) -> Option<String> {
        self.state.lock().unwrap().icon_name.clone()
    }

    /// Gets an additional path to lookup the icon in.
    pub fn icon_theme_path(&self) -> Option<String> {
        self.state.lock().unwrap().icon_theme_path.clone()
    }

    /// Refresh the Item's menu layout.
    pub async fn refresh_layout_async(&self) {
        let Some(menu_proxy) = self.menu_proxy() else {
            return;
        };

        match menu_proxy.get_layout(0, -1, &[]).await {
            Ok((rev, layout)) => {
                let mut guard = self.state.lock().unwrap();
                guard.layout_rev = Some(rev);
                guard.layout = Some(layout);
            }
            Err(err) => tracing::warn!("Could no get layout: {err}"),
        }
    }

    /// Refresh the Item's menu layout.
    pub fn refresh_layout(&self) {
        self.refresh_layout_async().block_on_tokio()
    }

    /// Apply a closure to the item's layout, forwarding the result.
    pub fn with_layout<F, Ret>(&self, closure: F) -> Ret
    where
        F: FnOnce(Option<&Node>) -> Ret,
    {
        closure(self.state.lock().unwrap().layout.as_ref())
    }

    /// Send a hover event to a node of the remote DBusMenu.
    pub async fn hover_async(&self, node_id: i32) {
        let Some(menu_proxy) = self.menu_proxy() else {
            return;
        };

        let _ = menu_proxy.event(node_id, "hovered", &0i32.into(), 0).await;
    }

    /// Send a hover event to a node of the remote DBusMenu.
    pub fn hover(&self, node_id: i32) {
        self.hover_async(node_id).block_on_tokio()
    }

    /// Send a click event to a node of the remote DBusMenu.
    pub async fn click_async(&self, node_id: i32) {
        let Some(menu_proxy) = self.menu_proxy() else {
            return;
        };

        let _ = menu_proxy.event(node_id, "clicked", &0i32.into(), 0).await;
    }

    /// Send a click event to a node of the remote DBusMenu.
    pub fn click(&self, node_id: i32) {
        self.click_async(node_id).block_on_tokio()
    }

    /// Notifies the remote DBusMenu that it's about to be opened, and refresh the layout if
    /// needed.
    pub async fn about_to_show_async(&self) {
        let Some(menu_proxy) = self.menu_proxy() else {
            return;
        };

        match menu_proxy.about_to_show(0).await {
            Ok(refresh) => {
                if refresh {
                    self.refresh_layout_async().await
                }
            }
            Err(err) => tracing::warn!("{err}"),
        };
    }

    /// Notifies the remote DBusMenu that it's about to be opened, and refresh the layout if
    /// needed.
    pub fn about_to_show(&self) {
        self.about_to_show_async().block_on_tokio()
    }

    /// Gets the item's name.
    pub fn name(&self) -> String {
        self.state.lock().unwrap().name.clone()
    }

    /// Gets the item's DBusMenu proxy.
    pub fn menu_proxy(&self) -> Option<DBusMenuProxy<'static>> {
        self.state.lock().unwrap().menu_proxy.clone()
    }

    /// Gets the item's StatusNotifierItem proxy.
    pub fn proxy(&self) -> ItemProxy<'static> {
        self.state.lock().unwrap().item_proxy.clone()
    }

    /// Create a [`WeakItem`] pointing to the same data.
    pub fn downgrade(&self) -> WeakItem {
        WeakItem(Arc::downgrade(&self.state))
    }
}

impl WeakItem {
    /// Tries to upgrade to an owning [`Item`], returning [None] if the data has been destroyed.
    pub fn upgrade(&self) -> Option<Item> {
        self.0.upgrade().map(|state| Item { state })
    }
}
