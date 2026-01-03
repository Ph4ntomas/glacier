//! StatusNotifierHost implementation.
//!
//! Every [`Host`] connects to a StatusNotifierWatcher to receive registration and un-registration
//! events, and maintain a list of [`Item`]. This is meant as a building block for a system tray.

use std::{
    pin::Pin,
    sync::{Arc, Mutex, Weak},
};

use futures::prelude::*;
use zbus::{Connection, interface, names::WellKnownName};

use crate::protocols::status_notifier::{
    Item,
    watcher_proxy::{StatusNotifierItemRegistered, StatusNotifierItemUnregistered, WatcherProxy},
};

const SERVICE_PREFIX: &str = "org.kde.StatusNotifierHost";

pub type EventStream = Pin<Box<dyn Stream<Item = Event> + Send>>;

struct Inner {
    connection: zbus::Connection,
    name: WellKnownName<'static>,
    watcher_proxy: WatcherProxy<'static>,
    items: Vec<Item>,
}

/// Events raised by [`Host`] when items appears or disappear.
pub enum Event {
    ItemRegistered,
    ItemUnregistered,
    Error(String),
}

/// Host implementation.
///
/// See module level [documentation] for more information.
///
/// [documentation]: self
#[derive(Clone)]
pub struct Host {
    state: Arc<Mutex<Inner>>,
}

/// Non-owning [`Host`].
#[derive(Clone)]
pub struct WeakHost(Weak<Mutex<Inner>>);

#[interface(name = "org.kde.StatusNotifierHost")]
impl Host {}

impl Host {
    /// Create a new [`Host`].
    pub async fn new<S>(connection: &Connection, id: S) -> Self
    where
        S: AsRef<str>,
    {
        let watcher_proxy = WatcherProxy::new(connection)
            .await
            .expect("No Watcher available.");
        let name: WellKnownName<'static> = format!("{SERVICE_PREFIX}-{}", id.as_ref())
            .try_into()
            .unwrap();

        connection
            .request_name(name.as_ref())
            .await
            .expect("Could not request name");

        watcher_proxy
            .register_status_notifier_host(name.as_str())
            .await
            .expect("Could not connect to watcher.");

        let inner = Inner {
            connection: connection.clone(),
            name,
            watcher_proxy,
            items: Vec::new(),
        };

        Self {
            state: Arc::new(Mutex::new(inner)),
        }
    }

    /// Get a stream of registration and un-registration events.
    pub async fn item_stream(&self) -> EventStream {
        let watcher_proxy = self.state.lock().unwrap().watcher_proxy.clone();

        let registered_stream = watcher_proxy
            .receive_status_notifier_item_registered()
            .await
            .expect("Could not connect to item_registered stream.")
            .then({
                let weak = self.downgrade();
                move |evt| {
                    let weak = weak.clone();
                    Box::pin(async move {
                        if let Some(host) = weak.upgrade() {
                            host.item_registered(evt).await
                        } else {
                            Event::Error("Host gone".to_string())
                        }
                    })
                }
            });

        let unregistered_stream = watcher_proxy
            .receive_status_notifier_item_unregistered()
            .await
            .expect("Could not connect to item_unregistered stream.")
            .then({
                let weak = self.downgrade();
                move |evt| {
                    let weak = weak.clone();
                    Box::pin(async move {
                        if let Some(host) = weak.upgrade() {
                            host.item_unregistered(evt).await
                        } else {
                            Event::Error("Host gone".to_string())
                        }
                    })
                }
            });

        let item_stream = futures::stream::once({
            let items = watcher_proxy
                .registered_status_notifier_items()
                .await
                .unwrap();
            let weak = self.downgrade();
            async move {
                if let Some(host) = weak.upgrade() {
                    for name in items {
                        host.add_item(name).await;
                    }
                    Event::ItemRegistered
                } else {
                    Event::Error("Host gone".to_string())
                }
            }
        });

        Box::pin(item_stream.chain(futures::stream_select!(
            registered_stream,
            unregistered_stream
        )))
    }

    /// Apply a closure to the [`Host`]'s items, forwarding the function return to the caller.
    pub fn with_items<F, Ret>(&self, closure: F) -> Ret
    where
        F: FnOnce(&Vec<Item>) -> Ret,
    {
        closure(&self.state.lock().unwrap().items)
    }

    /// Apply a closure to the [`Host`]'s items that may mutate them, forwarding the function
    /// return to the caller.
    pub fn with_items_mut<F, Ret>(&self, closure: F) -> Ret
    where
        F: FnOnce(&mut Vec<Item>) -> Ret,
    {
        closure(&mut self.state.lock().unwrap().items)
    }

    async fn add_item(&self, name: String) {
        let connection = self.state.lock().unwrap().connection.clone();
        let item = Item::new(&connection, name).await.unwrap();

        self.with_items_mut(|items| items.push(item))
    }

    async fn item_registered(&self, evt: StatusNotifierItemRegistered) -> Event {
        match evt.args() {
            Ok(args) => {
                self.add_item(args.service.to_string()).await;
                Event::ItemRegistered
            }
            Err(err) => Event::Error(err.to_string()),
        }
    }

    async fn item_unregistered(&self, evt: StatusNotifierItemUnregistered) -> Event {
        match evt.args() {
            Ok(args) => {
                self.with_items_mut(|items| {
                    items.retain(|i| i.name() != args.service);
                });

                Event::ItemUnregistered
            }
            Err(err) => Event::Error(err.to_string()),
        }
    }

    /// Create a new [`WeakHost`] pointing to the same data.
    pub fn downgrade(&self) -> WeakHost {
        WeakHost(Arc::downgrade(&self.state))
    }
}

impl WeakHost {
    /// Attempt to upgrade this object to a [`Host`]. Return None if the data has been destroyed
    /// already.
    pub fn upgrade(&self) -> Option<Host> {
        self.0.upgrade().map(|state| Host { state })
    }
}

impl Drop for Inner {
    fn drop(&mut self) {
        if let Ok(handle) = tokio::runtime::Handle::try_current() {
            handle.block_on(async {
                if let Err(e) = self.connection.release_name(self.name.as_ref()).await {
                    tracing::error!("Could not release {}: {}", self.name.as_str(), e);
                }
            })
        };

        // If there's no current runtime, it's likely we're stopping the config. No need to release
        // the well known name in that case.
    }
}
