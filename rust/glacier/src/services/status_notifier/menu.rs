use futures::{prelude::*, stream::AbortHandle};
use indexmap::IndexMap;
use std::{collections::HashSet, pin::Pin};

use crate::protocols::status_notifier as sni;

pub use sni::layout::Properties;
pub use sni::layout::ToggleType;
pub use sni::layout::Type;

pub struct LayoutUpdate {
    pub revision: u32,
    pub node: sni::layout::Node,
}

pub struct PropertyUpdate {
    pub updates: Vec<(i32, sni::layout::Properties)>,
    pub removal: Vec<(i32, Vec<String>)>,
}

pub struct FlatLayout {
    properties: IndexMap<i32, (i32, sni::layout::Properties)>,
}

pub enum Event {
    LayoutUpdate(LayoutUpdate),
    PropertyUpdate(PropertyUpdate),
}

pub struct Menu {
    revision: u32,
    layout: FlatLayout,
    abort_handle: Option<AbortHandle>,

    remote: sni::Menu,
}

impl FlatLayout {
    pub fn build(node: sni::layout::Node) -> Self {
        let sni::layout::Node {
            id,
            props,
            children,
        } = node;

        let mut properties = IndexMap::new();

        properties.insert(id, (id, props));

        for child in children {
            let child_id = child.id;
            let node = Self::build(child);

            properties.extend(node.properties);
            properties.entry(child_id).and_modify(|entry| entry.0 = id);
        }

        Self { properties }
    }

    pub fn update_layout(&mut self, node: sni::layout::Node) {
        // special case, this is the toplevel node.
        if node.id == 0 {
            let Self { properties } = Self::build(node);

            self.properties = properties;
            return;
        }

        self.properties.shift_remove(&node.id);

        let mut to_remove = vec![node.id];
        while let Some(id) = to_remove.pop() {
            to_remove.extend(
                self.properties
                    .extract_if(.., |_, v| v.0 == id)
                    .map(|(k, _)| k),
            );
        }

        let Self { properties } = Self::build(node);
        self.properties.extend(properties);
    }

    pub fn update_properties(
        &mut self,
        updates: Vec<(i32, sni::layout::Properties)>,
        removal: Vec<(i32, Vec<String>)>,
    ) -> Vec<(i32, sni::layout::Properties)> {
        let mut change_set: HashSet<i32> = HashSet::new();

        for (node_id, props) in updates {
            self.properties
                .entry(node_id)
                .and_modify(move |p| p.1.update(props));

            change_set.insert(node_id);
        }

        for (node_id, props) in removal {
            self.properties
                .entry(node_id)
                .and_modify(move |p| p.1.remove(props));

            change_set.insert(node_id);
        }

        let mut changed = Vec::new();

        for node_id in change_set.into_iter() {
            if let Some(prop) = self.properties.get(&node_id) {
                changed.push((node_id, prop.1.clone()));
            }
        }

        changed
    }
}

impl Menu {
    pub async fn new(remote: sni::Menu) -> zbus::Result<Self> {
        let (revision, root_node) = remote.get_layout(0, -1, &[]).await?;
        let layout = FlatLayout::build(root_node);

        Ok(Self {
            revision,
            layout,
            abort_handle: None,

            remote,
        })
    }

    pub async fn event_stream(&mut self) -> Pin<Box<dyn Stream<Item = Event> + Send>> {
        let signal_stream = self
            .remote
            .signal_stream()
            .await
            .then({
                let remote = self.remote.clone();
                move |sig| Self::signal_to_event(sig, remote.clone())
            })
            .filter_map(future::ready)
            .boxed();

        let (stream, handle) = stream::abortable(signal_stream);
        self.abort_handle = Some(handle);

        stream.boxed()
    }

    pub async fn pre_open(&self, node_id: i32) -> Option<LayoutUpdate> {
        match self.remote.about_to_show(node_id).await {
            Ok(true) => self
                .remote
                .get_layout(node_id, 1, &[])
                .await
                .inspect_err(|e| tracing::warn!("While refreshing {node_id}: {e}"))
                .map(|(revision, node)| LayoutUpdate { revision, node })
                .ok(),
            Ok(false) => None,
            Err(e) => {
                tracing::debug!("While calling about_to_show({node_id}): {e}");
                None
            }
        }
    }

    pub fn on_open<F>(&self, parent_node: i32, callback: F)
    where
        F: FnOnce(&mut dyn Iterator<Item = (i32, &sni::layout::Properties)>) + Send + 'static,
    {
        let mut children = self
            .layout
            .properties
            .iter()
            .skip(1) // skip node 0.
            .filter(|(_, (parent_id, _))| parent_id == &parent_node)
            .map(|(id, (_, props))| (*id, props));

        callback(&mut children);
    }

    pub async fn on_click(&self, node_id: i32) {
        if let Err(e) = self.remote.click(node_id).await {
            tracing::warn!("{e}");
        }
    }

    pub async fn on_hover(&self, node_id: i32) {
        if let Err(e) = self.remote.hover(node_id).await {
            tracing::warn!("{e}");
        }
    }

    pub fn on_layout_update(&mut self, update: LayoutUpdate) -> Option<i32> {
        let LayoutUpdate { revision, node } = update;

        if revision > self.revision {
            let id = node.id;
            self.layout.update_layout(node);
            Some(id)
        } else {
            None
        }
    }

    pub fn on_property_update(
        &mut self,
        update: PropertyUpdate,
    ) -> Vec<(i32, sni::layout::Properties)> {
        let PropertyUpdate { updates, removal } = update;

        self.layout.update_properties(updates, removal)
    }

    async fn signal_to_event(signal: sni::menu::Signal, remote: sni::Menu) -> Option<Event> {
        use sni::menu::Signal;
        match signal {
            Signal::PropertiesUpdated { updates, removal } => {
                Some(PropertyUpdate { updates, removal }.into())
            }
            Signal::LayoutUpdated {
                revision: _,
                parent_node,
            } => remote
                .get_layout(parent_node, -1, &[])
                .await
                .ok()
                .map(|(revision, node)| LayoutUpdate { revision, node }.into()),
        }
    }
}

impl From<PropertyUpdate> for Event {
    fn from(value: PropertyUpdate) -> Self {
        Self::PropertyUpdate(value)
    }
}

impl From<LayoutUpdate> for Event {
    fn from(value: LayoutUpdate) -> Self {
        Self::LayoutUpdate(value)
    }
}

impl Drop for Menu {
    fn drop(&mut self) {
        if let Some(handle) = self.abort_handle.as_ref() {
            handle.abort();
        }
    }
}
