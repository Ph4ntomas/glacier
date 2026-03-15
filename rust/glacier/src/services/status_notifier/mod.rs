use futures::{prelude::*, stream::SelectAll};
use snowcap_api::signal::{HandlerPolicy, Signaler};
use std::slice::Iter;
use tokio::sync::mpsc;

use crate::protocols::status_notifier::{self as sni, host::Event};

pub mod item;
pub mod menu;

pub mod signal {
    use crate::protocols::status_notifier::{self as sni};
    use snowcap_api::signal::Signal;

    #[derive(Clone, Debug, Signal)]
    pub struct ItemAdded(pub super::item::State);

    #[derive(Clone, Debug, Signal)]
    pub struct ItemUpdated(pub super::item::UniqueId, pub super::item::Update);

    #[derive(Clone, Debug, Signal)]
    pub struct ItemRemoved(pub super::item::UniqueId);

    #[derive(Clone, Debug, Signal)]
    pub struct LayoutChanged {
        pub item_id: super::item::UniqueId,
        pub node_id: i32,
    }

    #[derive(Clone, Debug, Signal)]
    pub struct MenuPropertyChanged {
        pub item_id: super::item::UniqueId,
        pub changeset: Vec<(i32, sni::layout::Properties)>,
    }
}

type WithItemsFn = Box<dyn FnOnce(Iter<item::Item>) + Send>;
type OpenMenuCallback =
    Box<dyn FnOnce(&mut dyn Iterator<Item = (i32, &sni::layout::Properties)>) + Send>;

enum MenuTask {
    Open(i32, OpenMenuCallback),
    Click(i32),
    Hover(i32),
}

enum Task {
    RunWithItems(WithItemsFn),
    RunWithItem(item::UniqueId, Box<dyn FnOnce(&item::Item) + Send>),
    ActivateItem(item::UniqueId),
    Menu(item::UniqueId, MenuTask),
}

pub struct State {
    connection: zbus::Connection,
    host: sni::Host,
    items: Vec<item::Item>,
    signaler: Signaler,
}

#[derive(Clone)]
pub struct StatusNotifier {
    signaler: Signaler,
    sender: mpsc::UnboundedSender<Task>,
}

impl StatusNotifier {
    const SNI_HOST_ID: &str = "glacier-status-notifier-host";

    pub async fn new(connection: zbus::Connection) -> Self {
        let host = sni::Host::new(&connection, Self::SNI_HOST_ID).await;

        let (sender, task_receiver) = mpsc::unbounded_channel();

        let state = State {
            connection,
            host,
            items: Default::default(),
            signaler: Default::default(),
        };

        let ret = Self {
            signaler: state.signaler.clone(),
            sender,
        };

        state.spawn(task_receiver);

        ret
    }

    /// Run a closure acting on [`Item`]s in the context of the service.
    ///
    /// [`Item`]: item::Item
    pub fn run_with_items<F>(&self, processor: F)
    where
        F: FnOnce(Iter<item::Item>) + Send + 'static,
    {
        let _ = self.sender.send(Task::RunWithItems(Box::new(processor)));
    }

    pub async fn with_items<F, Ret>(&self, processor: F) -> Ret
    where
        F: FnOnce(Iter<item::Item>) -> Ret + Send + 'static,
        Ret: Send + 'static,
    {
        use tokio::sync::oneshot;
        let (sender, receiver) = oneshot::channel();

        self.run_with_items(move |items| {
            let _ = sender.send(processor(items));
        });

        receiver.await.expect("Failed to get result.")
    }

    /// Run a closure acting on a single [`Item`] in the context of the service.
    ///
    /// [`Item`]: item::Item
    pub fn run_with_item<F>(&self, item_id: &item::UniqueId, processor: F)
    where
        F: FnOnce(&item::Item) + Send + 'static,
    {
        let _ = self
            .sender
            .send(Task::RunWithItem(item_id.to_owned(), Box::new(processor)));
    }

    pub fn activate_item(&self, item_id: &item::UniqueId) {
        let _ = self.sender.send(Task::ActivateItem(item_id.to_owned()));
    }

    pub fn click_menu(&self, item_id: &item::UniqueId, node_id: i32) {
        let _ = self
            .sender
            .send(Task::Menu(item_id.to_owned(), MenuTask::Click(node_id)));
    }

    pub fn hover_menu(&self, item_id: &item::UniqueId, node_id: i32) {
        let _ = self
            .sender
            .send(Task::Menu(item_id.to_owned(), MenuTask::Hover(node_id)));
    }

    pub fn open_menu<F>(&self, item_id: &item::UniqueId, node_id: i32, callback: F)
    where
        F: FnOnce(&mut dyn Iterator<Item = (i32, &sni::layout::Properties)>) + Send + 'static,
    {
        let _ = self.sender.send(Task::Menu(
            item_id.to_owned(),
            MenuTask::Open(node_id, Box::new(callback)),
        ));
    }

    pub fn connect<F, S>(&self, callback: F) -> snowcap_api::signal::Handle<S>
    where
        S: snowcap_api::signal::Signal,
        F: Fn(S) -> HandlerPolicy + Send + Sync + 'static,
    {
        self.signaler.connect(callback)
    }

    pub fn signaler(&self) -> Signaler {
        self.signaler.clone()
    }
}

impl State {
    fn spawn(mut self, mut task_receiver: mpsc::UnboundedReceiver<Task>) {
        tokio::spawn({
            async move {
                let mut host_event_stream = self.host.item_stream().await;
                let mut item_update_streams = SelectAll::new();
                let mut menu_event_streams = SelectAll::new();

                loop {
                    tokio::select! {
                        Some(event) = host_event_stream.next() => {
                            self.on_host_event(event, &mut item_update_streams, &mut menu_event_streams).await;
                        }
                        Some(task) = task_receiver.recv() => {
                            self.on_task(task).await;
                        }
                        item_update = item_update_streams.next(), if !item_update_streams.is_empty() => {
                            let Some((item_id, update)) = item_update else {
                                continue;
                            };

                            self.on_item_update(item_id, update, &mut menu_event_streams).await;
                        }
                        menu_event = menu_event_streams.next(), if !menu_event_streams.is_empty() => {
                            let Some((item_id, event)) = menu_event else {
                                continue;
                            };

                            self.on_menu_event(item_id, event);
                        }
                        else => break
                    }
                }
            }
        });
    }

    fn find_item(&self, uid: &item::UniqueId) -> Option<&item::Item> {
        self.items.iter().find(|i| i.unique_id() == uid)
    }

    fn find_item_mut(&mut self, uid: &item::UniqueId) -> Option<&mut item::Item> {
        self.items.iter_mut().find(|i| i.unique_id() == uid)
    }

    fn remove_item(&mut self, bus_id: &str) {
        let items: Vec<_> = self
            .items
            .extract_if(.., |i| i.bus_id() == bus_id)
            .collect();

        for item in items {
            self.signaler
                .emit(signal::ItemRemoved(item.unique_id().to_owned()))
        }
    }

    async fn on_task(&mut self, task: Task) {
        match task {
            Task::RunWithItems(f) => f(self.items.iter()),
            Task::RunWithItem(id, f) => {
                if let Some(item) = self.find_item(&id) {
                    f(item)
                }
            }
            Task::ActivateItem(id) => {
                if let Some(item) = self.find_item(&id) {
                    item.activate().await;
                }
            }
            Task::Menu(item_id, MenuTask::Open(node_id, callback)) => {
                let signaler = self.signaler.clone();
                if let Some(menu) = self.find_item_mut(&item_id).and_then(|i| i.menu_mut()) {
                    if let Some(update) = menu.pre_open(node_id).await {
                        menu.on_layout_update(update);
                        signaler.emit(signal::LayoutChanged { item_id, node_id });
                    }

                    menu.on_open(node_id, callback);
                }
            }
            Task::Menu(item_id, MenuTask::Click(id)) => {
                if let Some(menu) = self.find_item_mut(&item_id).and_then(|i| i.menu_mut()) {
                    menu.on_click(id).await
                }
            }
            Task::Menu(item_id, MenuTask::Hover(id)) => {
                if let Some(menu) = self.find_item_mut(&item_id).and_then(|i| i.menu_mut()) {
                    menu.on_hover(id).await
                }
            }
        }
    }

    async fn on_host_event(
        &mut self,
        event: Event,
        item_update_streams: &mut SelectAll<stream::BoxStream<'_, (item::UniqueId, item::Update)>>,
        menu_event_streams: &mut SelectAll<stream::BoxStream<'_, (item::UniqueId, menu::Event)>>,
    ) {
        match event {
            Event::ItemRegistered(item) => {
                let Ok(mut item) = item::Item::new(&self.connection, item).await else {
                    tracing::error!("Could not initialize item");
                    return;
                };

                self.remove_item(item.bus_id());

                let uid = item.unique_id().to_owned();

                item_update_streams.push(item.update_stream().await);

                if let Some(menu) = item.menu_mut() {
                    menu_event_streams.push(
                        menu.event_stream()
                            .await
                            .map({
                                let uid = uid.clone();
                                move |evt| (uid.clone(), evt)
                            })
                            .boxed(),
                    );
                };

                let state = item.state().clone();
                self.items.push(item);

                self.signaler.emit(signal::ItemAdded(state));
            }
            Event::ItemUnregistered(bus_id) => {
                self.remove_item(&bus_id);
            }
            Event::Error(e) => tracing::error!("{e}"),
        }
    }

    async fn on_item_update(
        &mut self,
        item_id: item::UniqueId,
        update: item::Update,
        menu_event_streams: &mut SelectAll<stream::BoxStream<'_, (item::UniqueId, menu::Event)>>,
    ) {
        let signaler = self.signaler.clone();
        let connection = self.connection.clone();

        if let Some(item) = self.find_item_mut(&item_id) {
            item.apply_update(update.clone());

            if matches!(update, item::Update::Menu) {
                let uid = item_id.clone();
                item.refresh_menu(&connection).await;

                if let Some(menu) = item.menu_mut() {
                    menu_event_streams.push(
                        menu.event_stream()
                            .await
                            .map(move |evt| (uid.clone(), evt))
                            .boxed(),
                    );
                }
            }

            signaler.emit(signal::ItemUpdated(item_id, update));
        }
    }

    fn on_menu_event(&mut self, item_id: item::UniqueId, event: menu::Event) {
        if let Some(item) = self.find_item_mut(&item_id) {
            let Some(menu) = item.menu_mut() else {
                return;
            };

            match event {
                menu::Event::LayoutUpdate(update) => {
                    if let Some(node_id) = menu.on_layout_update(update) {
                        self.signaler
                            .emit(signal::LayoutChanged { item_id, node_id });
                    }
                }
                menu::Event::PropertyUpdate(update) => {
                    let changeset = menu.on_property_update(update);

                    self.signaler.emit(signal::MenuPropertyChanged {
                        item_id: item_id.clone(),
                        changeset,
                    })
                }
            };
        }
    }
}
