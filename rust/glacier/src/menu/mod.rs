use std::{
    collections::HashSet,
    fmt::Debug,
    slice::{Iter, IterMut},
};

use snowcap_api::{
    input::KeyEvent,
    popup::{self, AsParent, PopupHandle},
    signal::{Handle as SigHandle, Signaler, WeakSignaler},
    surface::{SurfaceEvent, SurfaceHandle},
    widget::{
        Background, Length, Padding, Point, Program, WidgetDef,
        base::WidgetBase,
        column::Column,
        container::{self, Container},
        mouse_area::MouseArea,
        row::Row,
        signal::RequestClose,
    },
    xkbcommon::xkb,
};

use crate::color;

pub mod signal {
    use snowcap_api::signal::Signal;

    use super::message;

    #[derive(Debug, Clone, Signal)]
    pub struct RequestSubmenuClose;

    #[derive(Clone, Signal)]
    pub struct RequestSubmenuOpen(pub(super) message::InFlightMenu);

    impl RequestSubmenuOpen {
        pub fn new<Msg>(menu: super::Menu<Msg>) -> Self
        where
            Msg: Send + 'static,
        {
            Self(menu.into())
        }
    }
}

pub mod style;
#[doc(inline)]
pub use style::Style;

pub mod entry;
pub use entry::Entry;
pub use entry::label;

pub mod message;
pub use message::Action;
pub use message::Message;

pub struct Menu<Msg = message::Message> {
    base: WidgetBase,
    builder: message::Builder<Msg>,
    handle: Option<SurfaceHandle<Msg>>,

    entries: Vec<Entry<Msg>>,
    style: Style,
    key_config: KeyConfig,

    selected: Option<usize>,
    hovered: Option<usize>,

    submenu_config: Option<Config>,
    submenu: Option<Submenu<Msg>>,
}

pub struct Handle<Msg = message::Message> {
    builder: message::Builder<Msg>,
    handle: PopupHandle<Msg>,
}

struct Submenu<Msg> {
    handle: Handle<Msg>,
    signaler: Signaler,
    sub_close_signal: SigHandle<signal::RequestSubmenuClose>,
    close_signal: SigHandle<RequestClose>,
}

#[derive(Default, Debug, Clone)]
pub struct Config {
    pub anchor: Option<popup::Anchor>,
    pub gravity: Option<popup::Gravity>,
    pub offset: Option<popup::Offset>,
    pub constraints_adjust: Option<popup::ConstraintsAdjust>,
    pub no_grab: bool,
    pub no_replace: bool,
}

/// [`Menu`] keyboard configuration.
#[derive(Default, Debug, Clone)]
pub struct KeyConfig {
    pub next: HashSet<xkb::Keysym>,
    pub prev: HashSet<xkb::Keysym>,
    pub submit: HashSet<xkb::Keysym>,
    pub open_menu: HashSet<xkb::Keysym>,
    pub close_menu: HashSet<xkb::Keysym>,
    pub close: HashSet<xkb::Keysym>,
}

/// Default [`Menu`] style.
pub fn default_style() -> Style {
    Style {
        bg_color: Some(color::from_hex("#2b2b2b")),
        width: Some(Length::Fixed(250.)),

        entry: style::Entry {
            default: style::EntryState {
                fg_color: Some(color::from_hex("#d7d7d7")),
                ..Default::default()
            },
            selected: style::EntryState {
                bg_color: Some(color::from_hex("#6B1ABC")),
                ..Default::default()
            },
            disabled: style::EntryState {
                fg_color: Some(color::from_hex("#5B5B5B")),
                ..Default::default()
            },
            height: 24.,
            padding: Some(Padding {
                left: 2.,
                right: 2.,
                ..Default::default()
            }),
        },
        menu_indicator: style::MenuIndicator {
            color: Some(color::from_hex("#7b7b7b")),
            width: Some(Length::Fixed(12.)),
            height: Some(Length::Fixed(12.)),
            ..Default::default()
        },
        separator: style::Separator {
            fg_color: Some(color::from_hex("#131313")),
            padding: Padding {
                top: 3.,
                bottom: 3.,
                left: 8.,
                right: 8.,
            },
            thickness: 1.,
            ..Default::default()
        },

        padding: None,
        spacing: Some(1.),
        border: None,
    }
}

/// Default keyboard configuration for [`Menu`]
pub fn default_key_config() -> KeyConfig {
    KeyConfig {
        next: [xkb::Keysym::Down].into(),
        prev: [xkb::Keysym::Up].into(),
        submit: [xkb::Keysym::Return].into(),
        open_menu: [xkb::Keysym::Right].into(),
        close_menu: [xkb::Keysym::Left].into(),
        close: [xkb::Keysym::Escape].into(),
    }
}

impl<Msg> Handle<Msg> {
    pub fn close(self) {
        self.handle.close();
    }

    pub fn send_message(&self, message: Msg) {
        self.handle.send_message(message);
    }
}

impl<Msg> Handle<Msg>
where
    Msg: From<Message>,
{
    pub fn next(&self) {
        let message = self.builder.menu(Action::Next);
        self.handle.send_message(message);
    }

    pub fn prev(&self) {
        let message = self.builder.menu(Action::Prev);
        self.handle.send_message(message);
    }

    pub fn submit(&self) {
        let message = self.builder.menu(Action::Submit);
        self.handle.send_message(message);
    }
}

impl Config {
    pub fn new() -> Self {
        Default::default()
    }

    pub fn anchor(self, anchor: popup::Anchor) -> Self {
        Self {
            anchor: Some(anchor),
            ..self
        }
    }

    pub fn gravity(self, gravity: popup::Gravity) -> Self {
        Self {
            gravity: Some(gravity),
            ..self
        }
    }

    pub fn offset(self, offset: popup::Offset) -> Self {
        Self {
            offset: Some(offset),
            ..self
        }
    }

    pub fn constraint_adjustment(self, adjustment: popup::ConstraintsAdjust) -> Self {
        Self {
            constraints_adjust: Some(adjustment),
            ..self
        }
    }

    /// Don't grab keyboard interactivity.
    pub fn grabless(self) -> Self {
        Self {
            no_grab: true,
            ..self
        }
    }

    /// Sets the [`no_replace`] flag.
    ///
    /// [`no_replace`]: Config::no_replace
    pub fn fail_on_replace(self) -> Self {
        Self {
            no_replace: true,
            ..self
        }
    }
}

/// default_* methods for all Menu<Msg>
impl<Msg> Menu<Msg> {
    /// Default [`Menu`] view.
    pub fn default_view(entries: Vec<WidgetDef<Msg>>, style: &Style) -> WidgetDef<Msg> {
        let column = Column::new_with_children(entries);

        let mut container = Container::new(column);

        container.width = style.width;
        container.padding = style.padding;
        container.style = Some(container::Style {
            background: style.bg_color.map(Background::Color),
            border: style.border,
            ..Default::default()
        });

        container.into()
    }
}

impl<Msg> Menu<Msg>
where
    Msg: From<Message> + Clone + 'static,
{
    pub fn default_keyboard_handler(
        key_event: KeyEvent,
        key_config: &KeyConfig,
        weak_signaler: &WeakSignaler,
        builder: message::Builder<Msg>,
    ) {
        if key_event.captured || !key_event.pressed {
            return;
        }

        let Some(signaler) = weak_signaler.upgrade() else {
            return;
        };

        let KeyConfig {
            next,
            prev,
            submit,
            open_menu,
            close_menu,
            close,
        } = key_config.clone();

        let key = key_event.key;

        let action = if close.contains(&key) {
            Action::Close
        } else if next.contains(&key) {
            Action::Next
        } else if prev.contains(&key) {
            Action::Prev
        } else if submit.contains(&key) {
            Action::Submit
        } else if open_menu.contains(&key) {
            Action::OpenMenu
        } else if close_menu.contains(&key) {
            signaler.emit(signal::RequestSubmenuClose);
            return;
        } else {
            return;
        };

        let message = builder.menu(action);
        signaler.emit(snowcap_api::widget::signal::Message(message));
    }
}

/// Lifetime
impl<Msg> Menu<Msg>
where
    Msg: From<Message> + TryInto<Message> + Clone + Send + 'static,
{
    const PROGRAM_NAME: &'static str = "glacier::Menu";

    pub fn new() -> Self {
        let base = WidgetBase::new(Self::PROGRAM_NAME);
        let builder = message::Builder::new(base.id());

        Self {
            base,
            builder,
            handle: None,

            entries: Default::default(),
            style: default_style(),
            key_config: default_key_config(),

            selected: None,
            hovered: None,

            submenu_config: None,
            submenu: None,
        }
    }

    pub fn connect<S, F>(&self, callback: F) -> snowcap_api::signal::Handle<S>
    where
        S: snowcap_api::signal::Signal,
        F: Fn(S) -> snowcap_api::signal::HandlerPolicy + Sync + Send + 'static,
    {
        self.base.signaler().connect(callback)
    }

    /// Open this [`Menu`] as a popup.
    pub fn popup(
        mut self,
        parent: &impl AsParent,
        position: popup::Position,
        config: Config,
    ) -> Option<Handle<Msg>> {
        if self.submenu_config.is_none() {
            self.submenu_config = Some(config.clone());
        }

        let Config {
            anchor,
            gravity,
            offset,
            constraints_adjust,
            no_grab,
            no_replace,
        } = config;

        let weak_signaler = self.base.signaler().downgrade();
        let key_config = self.key_config.clone();
        let builder = self.builder.clone();

        let handle = popup::new_widget(
            self,
            parent,
            position,
            anchor,
            gravity,
            offset,
            constraints_adjust,
            no_grab,
            no_replace,
        );

        let handle = match handle {
            Ok(handle) => handle,
            Err(e) => {
                tracing::error!("Failed to spawn menu: {e}");
                return None;
            }
        };

        handle.on_key_event({
            let builder = builder.clone();
            move |_, key_event| {
                Self::default_keyboard_handler(
                    key_event,
                    &key_config,
                    &weak_signaler,
                    builder.clone(),
                );
            }
        });

        Some(Handle { builder, handle })
    }
}

impl<Msg> Menu<Msg> {
    pub fn add_entry(self, entry: Entry<Msg>) -> Self {
        let mut entries = self.entries;

        entries.push(entry);

        Self { entries, ..self }
    }

    pub fn add_separator(self) -> Self {
        let mut entries = self.entries;

        entries.push(Entry::separator());

        Self { entries, ..self }
    }

    pub fn entries(self, entries: impl IntoIterator<Item = Entry<Msg>>) -> Self {
        Self {
            entries: entries.into_iter().collect(),
            ..self
        }
    }

    pub fn submenu_config(self, config: Config) -> Self {
        Self {
            submenu_config: Some(config),
            ..self
        }
    }

    pub fn key_config(&self) -> &KeyConfig {
        &self.key_config
    }

    pub fn set_key_config(self, key_config: KeyConfig) -> Self {
        Self { key_config, ..self }
    }

    pub fn merge_key_config(self, key_config: KeyConfig) -> Self {
        let KeyConfig {
            next,
            prev,
            submit,
            open_menu,
            close_menu,
            close,
        } = key_config;

        let mut key_config = self.key_config;
        key_config.next = key_config.next.union(&next).cloned().collect();
        key_config.prev = key_config.prev.union(&prev).cloned().collect();
        key_config.submit = key_config.submit.union(&submit).cloned().collect();
        key_config.open_menu = key_config.open_menu.union(&open_menu).cloned().collect();
        key_config.close_menu = key_config.close_menu.union(&close_menu).cloned().collect();
        key_config.close = key_config.close.union(&close).cloned().collect();

        Self { key_config, ..self }
    }
}

impl<Msg> Menu<Msg>
where
    Msg: TryInto<Message> + From<Message> + Clone + 'static,
{
    fn make_entry_id(&self, id: usize) -> String {
        format!("#{}-{}", self.base, id)
    }

    fn view_entry(&self, entry: &Entry<Msg>, id: String, selected: bool) -> Option<WidgetDef<Msg>> {
        let style = &self.style;

        if entry.is_separator() {
            return Some(Entry::separator_view(&style.separator));
        }

        let view = Container::new(entry.view().unwrap_or_else(|| Row::new().into()))
            .width(Length::Fill)
            .into();

        let menu_indicator = if entry.is_menu() {
            Some(Entry::menu_indicator_view(
                &style.menu_indicator,
                entry.is_disabled(),
                selected,
            ))
        } else {
            None
        };

        let content = [Some(view), menu_indicator];

        let state_style = if entry.is_disabled() {
            style.entry.default.merge(&style.entry.disabled)
        } else if selected {
            style.entry.default.merge(&style.entry.selected)
        } else {
            style.entry.default.clone()
        };

        let row = Row::new_with_children(content.into_iter().flatten())
            .clip(true)
            .item_alignment(snowcap_api::widget::Alignment::Center)
            .height(Length::Fill)
            .width(Length::Fill);

        let mut entry_widget = Container::new(row)
            .id(id)
            .height(Length::Fixed(style.entry.height))
            .width(Length::Fill)
            .clip(true)
            .style(container::Style {
                background: state_style.bg_color.map(From::from),
                text_color: state_style.fg_color,
                border: state_style.border,
            });

        entry_widget.padding = style.entry.padding;

        Some(entry_widget.into())
    }
}

impl<Msg> Menu<Msg> {
    fn find_hovered(&self, point: Point) -> Option<usize> {
        let Padding { top, .. } = self.style.padding.unwrap_or_default();

        self.iter_entries()
            .enumerate()
            .scan((top, top), |state, (id, entry)| {
                let height = if entry.is_separator() {
                    let Padding { top, bottom, .. } = &self.style.separator.padding;

                    top + bottom + self.style.separator.thickness
                } else {
                    self.style.entry.height
                };

                state.0 = state.1;
                state.1 = state.0 + height;

                let id = if entry.is_disabled() { None } else { Some(id) };

                Some((*state, id))
            })
            .find_map(|(bound, id)| {
                if point.y >= bound.0 && point.y < bound.1 {
                    Some(id)
                } else {
                    None
                }
            })
            .flatten()
    }

    fn find_next(&self) -> Option<usize> {
        let pred_map = |(id, entry): (usize, &Entry<Msg>)| {
            if !entry.is_disabled() { Some(id) } else { None }
        };

        if let Some(id) = self.selected {
            let found = self
                .iter_entries()
                .enumerate()
                .skip(id + 1)
                .find_map(pred_map);

            if found.is_some() {
                return found;
            }
        };

        self.iter_entries().enumerate().find_map(pred_map)
    }

    fn find_prev(&self) -> Option<usize> {
        let pred_map = |(id, entry): (usize, &Entry<Msg>)| {
            if !entry.is_disabled() { Some(id) } else { None }
        };

        if let Some(id) = self.selected {
            let found = self
                .iter_entries()
                .enumerate()
                .take(id)
                .rev()
                .find_map(pred_map);

            if found.is_some() {
                return found;
            }
        }

        self.iter_entries().enumerate().rev().find_map(pred_map)
    }

    fn close_menu(&mut self) {
        let Some(Submenu {
            handle,
            signaler,
            sub_close_signal,
            close_signal,
        }) = self.submenu.take()
        else {
            return;
        };

        signaler.disconnect(sub_close_signal);
        signaler.disconnect(close_signal);
        drop(signaler);

        handle.close();
    }

    fn get_selected(&self) -> Option<&Entry<Msg>> {
        let id = self.selected?;

        self.entries.get(id)
    }

    fn get_selected_mut(&mut self) -> Option<&mut Entry<Msg>> {
        let id = self.selected?;

        self.entries.get_mut(id)
    }

    fn iter_entries(&self) -> Iter<'_, Entry<Msg>> {
        self.entries.iter()
    }

    fn iter_entries_mut(&mut self) -> IterMut<'_, Entry<Msg>> {
        self.entries.iter_mut()
    }
}

impl<Msg> Menu<Msg>
where
    Msg: From<Message> + TryInto<Message> + Clone + Send + 'static,
{
    fn select(&mut self, id: usize, hover: bool) {
        if Some(id) == self.selected {
            return;
        }

        self.close_menu();
        self.selected = Some(id);

        if let Some(selected) = self.get_selected_mut() {
            selected.update(Message::Entry(entry::Message::Hover).into());
        }

        if hover && self.get_selected().map(|e| e.is_menu()).unwrap_or(false) {
            self.open_entry()
        }
    }

    fn submit_entry(&mut self) -> bool {
        let Some(entry) = self.get_selected_mut() else {
            return false;
        };

        if entry.is_disabled() {
            return false;
        }

        entry.update(Message::Entry(entry::Message::Submit).into());

        entry.should_close_on_submit()
    }

    fn open_entry(&mut self) {
        let Some(entry) = self.get_selected_mut() else {
            return;
        };

        if entry.is_disabled() || !entry.is_menu() {
            return;
        }

        entry.update(Message::Entry(entry::Message::OpenMenu).into());
    }

    fn open_submenu(&mut self, submenu: Menu<Msg>) {
        let Some(id) = self.selected else {
            return;
        };

        let Some(entry) = self.get_selected() else {
            return;
        };

        if entry.is_disabled() || !entry.is_menu() {
            return;
        }

        let Some(handle) = self.handle.clone() else {
            return;
        };

        self.close_menu();

        let config = self
            .submenu_config
            .clone()
            .expect("Missing submenu config.");
        let position = popup::Position::at_widget(self.make_entry_id(id));

        let sub_close_signal = submenu.connect({
            let builder = self.builder.clone();
            let signaler = self.base.signaler();
            move |signal::RequestSubmenuClose| {
                let message = builder.menu(Action::CloseSubmenu);

                signaler.emit(snowcap_api::widget::signal::Message(message));

                snowcap_api::signal::HandlerPolicy::Keep
            }
        });

        let close_signal = submenu.connect({
            let builder = self.builder.clone();
            let signaler = self.base.signaler();
            move |snowcap_api::widget::signal::RequestClose| {
                let message = builder.menu(Action::Close);

                signaler.emit(snowcap_api::widget::signal::Message(message));

                snowcap_api::signal::HandlerPolicy::Keep
            }
        });

        let signaler = submenu.base.signaler();

        self.submenu = submenu
            .set_key_config(self.key_config.clone())
            .popup(&handle, position, config)
            .map(move |handle| Submenu {
                handle,
                signaler,
                sub_close_signal,
                close_signal,
            });
    }

    pub fn register_entry(&mut self, entry: &Entry<Msg>) {
        self.register_child(entry);

        if entry.is_menu()
            && let Some(signaler) = entry.signaler()
        {
            signaler.connect({
                let builder = self.builder.clone();
                let signaler = self.base.signaler();
                move |signal::RequestSubmenuOpen(menu)| {
                    let message = builder.menu(Action::OpenSubmenu(menu));

                    signaler.emit(snowcap_api::widget::signal::Message(message));
                    snowcap_api::signal::HandlerPolicy::Keep
                }
            });
        }
    }

    pub fn refresh_entries(&mut self, mut entries: Vec<Entry<Msg>>) {
        self.entries.drain(..).for_each(|mut e| {
            e.event(SurfaceEvent::Closing);
        });

        if let Some(surface) = self.handle.clone() {
            entries.iter_mut().for_each(|e| {
                e.event(SurfaceEvent::Created {
                    surface: surface.clone(),
                });
                self.register_entry(e);
            });
        }

        self.entries = entries;
    }
}

impl<Msg> Program for Menu<Msg>
where
    Msg: From<Message> + TryInto<Message> + Clone + Send + 'static,
{
    type Message = Msg;

    fn view(&self) -> Option<WidgetDef<Self::Message>> {
        let entries = self.iter_entries().enumerate().filter_map(|(id, entry)| {
            let selected = self.selected == Some(id);
            let id = self.make_entry_id(id);

            self.view_entry(entry, id, selected)
        });

        let content = Column::new_with_children(entries);

        let marea = MouseArea::new(content)
            .on_move({
                let builder = self.builder.clone();
                move |p| builder.menu(Action::RefreshHover(p))
            })
            .on_press(self.builder.menu(Action::MouseSubmit));

        let mut menu = Container::new(marea).style(container::Style {
            background: Some(crate::color::from_hex("#2b2b2b").into()),
            ..Default::default()
        });

        menu.width = self.style.width;

        Some(menu.into())
    }

    fn event(&mut self, event: SurfaceEvent<Self::Message>) {
        match &event {
            SurfaceEvent::Created { surface } => {
                self.handle = Some(surface.clone());

                let entries = std::mem::take(&mut self.entries);
                self.refresh_entries(entries);

                return;
            }
            SurfaceEvent::Closing => {
                self.base
                    .signaler()
                    .emit(snowcap_api::widget::signal::Closed);

                self.handle = None;
            }
            _ => {}
        };
        self.iter_entries_mut().for_each(|e| e.event(event.clone()));
    }

    fn signaler(&self) -> Option<snowcap_api::signal::Signaler> {
        Some(self.base.signaler())
    }

    fn update(&mut self, msg: Self::Message) {
        let mut closing = false;

        let action = match msg.clone().try_into() {
            Ok(Message::Menu { id, action }) if id == self.base.id() => action,
            Err(_) => {
                if let Some(submenu) = self.submenu.as_ref() {
                    submenu.handle.send_message(msg.clone());
                }

                self.iter_entries_mut().for_each(|e| e.update(msg.clone()));
                return;
            }
            _ => {
                if let Some(submenu) = self.submenu.as_ref() {
                    submenu.handle.send_message(msg);
                }

                return;
            }
        };

        match action {
            Action::RefreshHover(p) => {
                self.hovered = self.find_hovered(p);
                if let Some(id) = self.hovered {
                    self.select(id, true);
                }
            }
            Action::Next => {
                if let Some(id) = self.find_next() {
                    self.select(id, false)
                }
            }
            Action::Prev => {
                if let Some(id) = self.find_prev() {
                    self.select(id, false)
                }
            }
            Action::Submit => {
                closing = self.submit_entry();
            }
            Action::MouseSubmit => {
                if self.hovered.is_some() {
                    self.selected = self.hovered;
                    closing = self.submit_entry();
                }
            }
            Action::OpenMenu => {
                self.open_entry();
            }
            Action::OpenSubmenu(in_flight) => {
                if let Some(menu) = in_flight.take() {
                    self.open_submenu(menu);
                }
            }
            Action::CloseSubmenu => self.close_menu(),
            Action::Close => {
                closing = true;
            }
        };

        if closing {
            self.base
                .signaler()
                .emit(snowcap_api::widget::signal::RequestClose);
        }
    }
}

impl<Msg> Default for Menu<Msg>
where
    Msg: From<Message> + TryInto<Message> + Clone + Send + 'static,
{
    fn default() -> Self {
        Self::new()
    }
}
