//! StatusNotifieWatcher implementation.
//!
//! [`Watcher`] provides an implementation of the StatusNotifierWatcher protocol. Its role is to
//! maintain a list of StatusNotifierItem and StatusNotifierHost, and act as a mediator between
//! them.

use futures::prelude::*;
use zbus::{
    fdo::{DBusProxy, RequestNameFlags, RequestNameReply},
    interface,
    message::Header,
    names::{BusName, UniqueName, WellKnownName},
    object_server::SignalEmitter,
    zvariant::ObjectPath,
};

const NAME: WellKnownName =
    WellKnownName::from_static_str_unchecked("org.kde.StatusNotifierWatcher");
const OBJECT_PATH: ObjectPath = ObjectPath::from_static_str_unchecked("/StatusNotifierWatcher");
const PROTOCOL_VERSION: i32 = 0;

#[derive(Default, Debug)]
pub struct Watcher {
    items: Vec<(UniqueName<'static>, String)>,
    hosts: Vec<(UniqueName<'static>, String)>,
}

#[interface(name = "org.kde.StatusNotifierWatcher")]
impl Watcher {
    async fn register_status_notifier_host(
        &mut self,
        #[zbus(header)] header: Header<'_>,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
        service: String,
    ) {
        tracing::debug!("Registering host {}", service);
        let sender = header.sender().unwrap();

        let service = if service.starts_with('/') {
            format!("{sender}{service}")
        } else {
            service.to_string()
        };

        Self::status_notifier_host_registered(&emitter)
            .await
            .expect("Could not emit host registered signal.");
        self.hosts.push((sender.to_owned(), service))
    }

    async fn register_status_notifier_item(
        &mut self,
        #[zbus(header)] header: Header<'_>,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
        service: String,
    ) {
        tracing::debug!("Registering item {}", service);
        let sender = header.sender().unwrap();

        let service = if service.starts_with('/') {
            format!("{sender}{service}")
        } else {
            service.to_string()
        };

        Self::status_notifier_item_registered(&emitter, &service)
            .await
            .expect("Could not emit host registered signal.");
        self.items.push((sender.to_owned(), service))
    }

    #[zbus(signal)]
    async fn status_notifier_host_registered(emitter: &SignalEmitter<'_>) -> zbus::Result<()>;

    #[zbus(signal)]
    async fn status_notifier_host_unregistered(emitter: &SignalEmitter<'_>) -> zbus::Result<()>;

    #[zbus(signal)]
    async fn status_notifier_item_registered(
        emitter: &SignalEmitter<'_>,
        item: &str,
    ) -> zbus::Result<()>;

    #[zbus(signal)]
    async fn status_notifier_item_unregistered(
        emitter: &SignalEmitter<'_>,
        item: &str,
    ) -> zbus::Result<()>;

    #[zbus(property)]
    async fn is_status_notifier_host_registered(&self) -> bool {
        !self.hosts.is_empty()
    }

    #[zbus(property)]
    async fn protocol_version(&self) -> i32 {
        PROTOCOL_VERSION
    }

    #[zbus(property)]
    async fn registered_status_notifier_items(&self) -> Vec<String> {
        self.items
            .iter()
            .map(|(_, service)| service.clone())
            .collect()
    }
}

/// Create a StatusNotifierWatcherm, and start listening and forwarding registration events for
/// items and hosts.
pub async fn start_watcher(connection: &zbus::Connection) -> zbus::Result<()> {
    tracing::debug!("Starting SNI watcher");
    connection
        .object_server()
        .at(OBJECT_PATH, Watcher::default())
        .await?;

    let interface = connection
        .object_server()
        .interface::<_, Watcher>(OBJECT_PATH)
        .await
        .unwrap();

    let dbus_proxy = DBusProxy::new(connection).await?;
    let mut name_owner_changed_stream = dbus_proxy.receive_name_owner_changed().await?;

    let flags = RequestNameFlags::AllowReplacement.into();
    if dbus_proxy.request_name(NAME.as_ref(), flags).await? == RequestNameReply::InQueue {
        tracing::warn!("Bus name '{NAME}' already owned");
    }

    tokio::spawn({
        let connection = connection.clone();
        async move {
            let mut have_name = false;
            let unique_name = connection.unique_name().map(|name| name.as_ref());
            while let Some(evt) = name_owner_changed_stream.next().await {
                let Ok(args) = evt.args() else {
                    continue;
                };

                if args.name.as_ref() == NAME {
                    if args.new_owner().as_ref() == unique_name.as_ref() {
                        tracing::debug!("Acquired bus name: {NAME}");
                        have_name = true;
                    } else if have_name {
                        tracing::debug!("Lost bus name: {NAME}");
                        // TODO: Try to reconnect ?
                        have_name = false;
                    }
                    continue;
                }

                if args.new_owner().is_some() {
                    continue;
                }

                let mut interface = interface.get_mut().await;

                let (items, hosts) = match &args.name() {
                    BusName::Unique(name) => {
                        let name = name.clone().to_owned();
                        let removed_items: Vec<_> = interface
                            .items
                            .extract_if(.., |(unique_name, _)| unique_name == &name)
                            .collect();
                        let removed_hosts: Vec<_> = interface
                            .hosts
                            .extract_if(.., |(unique_name, _)| unique_name == &name)
                            .collect();

                        (removed_items, removed_hosts)
                    }
                    BusName::WellKnown(name) => {
                        let removed_items: Vec<_> = interface
                            .items
                            .extract_if(.., |(_, service)| service.as_str() == name.as_str())
                            .collect();
                        let removed_hosts: Vec<_> = interface
                            .hosts
                            .extract_if(.., |(_, service)| service.as_str() == name.as_str())
                            .collect();

                        (removed_items, removed_hosts)
                    }
                };

                let emitter = SignalEmitter::new(&connection, OBJECT_PATH).unwrap();
                for (_, service) in items {
                    Watcher::status_notifier_item_unregistered(&emitter, &service)
                        .await
                        .unwrap();
                }

                for (_, _) in hosts {
                    Watcher::status_notifier_host_unregistered(&emitter)
                        .await
                        .unwrap();
                }
            }
        }
    });

    Ok(())
}
