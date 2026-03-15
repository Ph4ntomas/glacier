use std::pin::Pin;

use super::menu;
use crate::protocols::status_notifier::item_proxy::ItemProxy;
use futures::{StreamExt, prelude::*};

#[derive(Clone, Copy, Debug)]
pub enum Signal {
    NewTitle,
    NewIcon,
    NewAttentionIcon,
    NewOverlayIcon,
    NewToolTip,
    NewMenu,
    NewStatus(Status),
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Status {
    Passive,
    Active,
    NeedsAttention,
    Unknown,
}

#[derive(Debug, Clone)]
pub struct Item {
    bus_id: String,
    destination: String,
    proxy: ItemProxy<'static>,
}

impl Item {
    pub async fn new(connection: &zbus::Connection, name: String) -> zbus::Result<Self> {
        let (destination, path) = if let Some(idx) = name.find('/') {
            (&name[..idx], &name[idx..])
        } else {
            (name.as_str(), "/StatusNotifierItem")
        };

        let proxy = ItemProxy::builder(connection)
            .cache_properties(zbus::proxy::CacheProperties::No)
            .destination(destination.to_string())?
            .path(path.to_string())?
            .build()
            .await?;

        let destination = destination.to_owned();

        Ok(Self {
            bus_id: name,
            destination,
            proxy,
        })
    }

    pub fn bus_id(&self) -> &str {
        &self.bus_id
    }

    pub fn proxy(&self) -> &ItemProxy<'static> {
        &self.proxy
    }

    pub async fn menu(&self, connection: &zbus::Connection) -> Option<menu::Menu> {
        let menu_path = self.proxy.menu().await.ok()?;

        menu::Menu::new(connection, self.destination.as_str(), menu_path)
            .await
            .ok()
    }

    pub async fn signal_stream(&self) -> Pin<Box<dyn Stream<Item = Signal> + Send>> {
        let title_stream = self
            .proxy
            .receive_new_title()
            .await
            .expect("Could not setup NewTitle signal stream.")
            .map(|_| Signal::NewTitle);

        let icon_stream = self
            .proxy
            .receive_new_icon()
            .await
            .expect("Could not setup NewIcon signal stream.")
            .map(|_| Signal::NewIcon);

        let attention_icon_stream = self
            .proxy
            .receive_new_attention_icon()
            .await
            .expect("Could not setup NewAttentionIcon signal stream.")
            .map(|_| Signal::NewAttentionIcon);

        let overlay_icon_stream = self
            .proxy
            .receive_new_overlay_icon()
            .await
            .expect("Could not setup NewOverlayIcon signal stream.")
            .map(|_| Signal::NewOverlayIcon);

        let tool_tip_stream = self
            .proxy
            .receive_new_tool_tip()
            .await
            .expect("Could not setup NewToolTip signal stream.")
            .map(|_| Signal::NewToolTip);

        let menu_stream = self
            .proxy
            .receive_new_menu()
            .await
            .expect("Could not setup NewMenu signal stream.")
            .map(|_| Signal::NewMenu);

        let status_stream = self
            .proxy
            .receive_new_status()
            .await
            .expect("Could not setup NewStatus signal stream.")
            .map(|status| {
                Signal::NewStatus(
                    status
                        .args()
                        .map(|args| Status::from(args.status))
                        .unwrap_or(Status::Unknown),
                )
            });

        Box::pin(futures::stream_select!(
            title_stream,
            icon_stream,
            attention_icon_stream,
            overlay_icon_stream,
            tool_tip_stream,
            menu_stream,
            status_stream
        ))
    }
}

impl From<&str> for Status {
    fn from(value: &str) -> Self {
        let lowercase = value.to_lowercase();

        match lowercase.as_str() {
            "passive" => Self::Passive,
            "active" => Self::Active,
            "needsattention" => Self::NeedsAttention,
            _ => Self::Unknown,
        }
    }
}

impl From<String> for Status {
    fn from(value: String) -> Self {
        value.as_str().into()
    }
}
