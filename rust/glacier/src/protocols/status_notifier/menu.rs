use std::pin::Pin;

use futures::prelude::*;
use zbus::zvariant::OwnedObjectPath;

use crate::protocols::status_notifier::{
    dbusmenu_proxy::{DBusMenuProxy, ItemsPropertiesUpdatedArgs},
    layout,
};

#[derive(Clone, Debug)]
pub enum Signal {
    LayoutUpdated {
        revision: u32,
        parent_node: i32,
    },
    PropertiesUpdated {
        updates: Vec<(i32, layout::Properties)>,
        removal: Vec<(i32, Vec<String>)>,
    },
}

#[derive(Debug, Clone)]
pub struct Menu {
    proxy: DBusMenuProxy<'static>,
}

impl Menu {
    pub async fn new(
        connection: &zbus::Connection,
        destination: &str,
        path: OwnedObjectPath,
    ) -> zbus::Result<Self> {
        let proxy = DBusMenuProxy::builder(connection)
            .destination(destination.to_owned())?
            .path(path)?
            .build()
            .await?;

        Ok(Self { proxy })
    }

    pub fn proxy(&self) -> &DBusMenuProxy<'static> {
        &self.proxy
    }

    pub async fn click(&self, node_id: i32) -> zbus::Result<()> {
        self.proxy.event(node_id, "clicked", &0i32.into(), 0).await
    }

    pub async fn hover(&self, node_id: i32) -> zbus::Result<()> {
        self.proxy.event(node_id, "hovered", &0i32.into(), 0).await
    }

    pub async fn about_to_show(&self, node_id: i32) -> zbus::Result<bool> {
        self.proxy.about_to_show(node_id).await
    }

    pub async fn get_layout(
        &self,
        node_id: i32,
        recursion_depth: i32,
        property_names: &[&str],
    ) -> zbus::Result<(u32, layout::Node)> {
        self.proxy
            .get_layout(node_id, recursion_depth, property_names)
            .await
    }

    pub async fn signal_stream(&self) -> Pin<Box<dyn Stream<Item = Signal> + Send>> {
        let layout_stream = self
            .proxy
            .receive_layout_updated()
            .await
            .expect("Could not setup Layout updated signal stream.")
            .filter_map(|update| {
                future::ready({
                    if let Ok(args) = update.args() {
                        Some(Signal::LayoutUpdated {
                            revision: args.revision,
                            parent_node: args.parent,
                        })
                    } else {
                        None
                    }
                })
            });

        let property_stream = self
            .proxy
            .receive_items_properties_updated()
            .await
            .expect("Could not setup Properties updated signal stream.")
            .filter_map(|update| {
                future::ready({
                    match update.args() {
                        Ok(ItemsPropertiesUpdatedArgs {
                            updated_props,
                            removed_props,
                            ..
                        }) => {
                            let removal = removed_props
                                .into_iter()
                                .map(|(id, v)| (id, v.into_iter().map(String::from).collect()))
                                .collect();

                            Some(Signal::PropertiesUpdated {
                                updates: updated_props,
                                removal,
                            })
                        }
                        Err(e) => {
                            tracing::warn!("{e}");
                            None
                        }
                    }
                })
            });

        Box::pin(futures::stream_select!(layout_stream, property_stream,))
    }
}
