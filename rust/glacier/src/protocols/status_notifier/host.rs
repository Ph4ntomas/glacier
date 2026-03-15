use std::pin::Pin;

use futures::prelude::*;
use zbus::{interface, names::WellKnownName};

use crate::protocols::status_notifier::watcher_proxy::{
    StatusNotifierItemRegistered, StatusNotifierItemUnregistered, WatcherProxy,
};

use super::item;

pub struct Host {
    connection: zbus::Connection,
    _name: WellKnownName<'static>,
    watcher_proxy: WatcherProxy<'static>,
}

pub enum Event {
    ItemRegistered(super::item::Item),
    ItemUnregistered(String),
    Error(String),
}

#[interface(name = "org.kde.StatusNotifierHost")]
impl Host {}

impl Host {
    const SERVICE_PREFIX: &str = "org.kde.StatusNotifierHost";

    pub async fn new<S>(connection: &zbus::Connection, id: S) -> Self
    where
        S: AsRef<str>,
    {
        let watcher_proxy = WatcherProxy::new(connection)
            .await
            .expect("No watcher available.");

        let _name: WellKnownName<'static> = format!("{}-{}", Self::SERVICE_PREFIX, id.as_ref())
            .try_into()
            .unwrap();

        connection
            .request_name(_name.as_ref())
            .await
            .expect("Could not request_name");

        watcher_proxy
            .register_status_notifier_host(_name.as_str())
            .await
            .expect("Could not connect to the watcher.");

        Self {
            connection: connection.clone(),
            _name,
            watcher_proxy,
        }
    }

    pub async fn item_stream(&self) -> Pin<Box<dyn Stream<Item = Event> + Send>> {
        let registered_stream = self
            .watcher_proxy
            .receive_status_notifier_item_registered()
            .await
            .expect("Could not connect to item_registered stream.")
            .then({
                let connection = self.connection.clone();
                move |event| Box::pin(Self::on_item_registered(connection.clone(), event))
            });

        let unregistered_stream = self
            .watcher_proxy
            .receive_status_notifier_item_unregistered()
            .await
            .expect("Could not connect to item_unregistered stream.")
            .then(|event| Box::pin(Self::on_item_unregistered(event)));

        let items = self
            .watcher_proxy
            .registered_status_notifier_items()
            .await
            .expect("Could not get current item list.");

        let item_stream = futures::stream::iter(items).then({
            let connection = self.connection.clone();
            move |name| Self::build_item(connection.clone(), name)
        });

        Box::pin(item_stream.chain(futures::stream_select!(
            registered_stream,
            unregistered_stream,
        )))
    }

    async fn build_item(connection: zbus::Connection, name: String) -> Event {
        match item::Item::new(&connection, name).await {
            Ok(item) => Event::ItemRegistered(item),
            Err(e) => Event::Error(e.to_string()),
        }
    }

    async fn on_item_registered(
        connection: zbus::Connection,
        event: StatusNotifierItemRegistered,
    ) -> Event {
        match event.args() {
            Ok(args) => Self::build_item(connection, args.service.to_string()).await,
            Err(e) => Event::Error(e.to_string()),
        }
    }

    async fn on_item_unregistered(event: StatusNotifierItemUnregistered) -> Event {
        match event.args() {
            Ok(args) => Event::ItemUnregistered(args.service.to_string()),
            Err(e) => Event::Error(e.to_string()),
        }
    }
}
