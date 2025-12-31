//! Glacier's menu.
//!
//! [`Menu`] are simple wrapper around Popups, displaying a list of entries in a single column.
//! Each Entry can be clicked or triggered via keyboard, and will further trigger an action.
//! Usually, triggering a [`Menu`] entry will perform some actions and close the menu. As a special
//! case, some entries might open a submenu in a new Popup surface instead, and triggering an entry
//! in that submenu will close the [`Menu`] as a whole.
//!
//! # Configuration
//!
//! As with other surface, [`Menu`]s default rendering can be customized by overriding their view
//! callback. It's also possible to change the keyboard interaction, and most importantly how
//! [`Menu`]'s Popups are opened in relation to one-another, as well as their opening widgets.
//!
//! Contrary to other surface however, [`Menu`]s uses [`Entry`] instead of the common [`Widget`] used
//! elsewhere. Each [`Entry`] can however contain standard [`Widget`]s, if that level of
//! customization is required.
//!
//! # Submenus
//!
//! Submenus are opened as nested popup. Most of the parent configuration is applied to the
//! submenu, to allow for a unified look & feel for the whole menu stack. Usually, the popup
//! configuration for the submenu will be slightly different, since they are positioned relative to
//! their parent, and not relative to their parent's anchor point. This can be controlled by
//! setting the [`child_popup_config`] on the root [`Menu`].
//!
//! [`Widget`]: crate::widget::Widget
//! [`child_popup_config`]: Menu::child_popup_config

use std::{
    collections::{HashMap, HashSet},
    fmt::Debug,
    sync::{Arc, Mutex, Weak},
};

use xkbcommon::xkb::Keysym;

use snowcap_api::{
    popup::{
        self, Anchor, AsParent, ConstraintsAdjust, Gravity, Offset, Parent, PopupHandle, Position,
    },
    widget::{
        Length, Program, WidgetDef,
        column::Column,
        container::{self, Container},
        mouse_area::MouseArea,
    },
};

use crate::{
    color,
    signal::{Emitter, WithEmitter},
    widget::WidgetMessage,
};

pub mod builder;
pub use builder::Builder;
pub use builder::builder;

pub mod entry;
pub use entry::Entry;

pub mod style;
#[doc(inline)]
pub use style::Style;

/// Menu's signals.
pub mod signal {
    use crate::signal::Signal;

    /// Emitted when a submenu need to be closed.
    #[derive(Clone, Copy, Debug, Signal)]
    pub struct RequestClose;

    /// Emitted when a [`Menu`] is closing.
    ///
    /// [`Menu`]: super::Menu
    #[derive(Clone, Copy, Debug, Signal)]
    pub struct Closing;

    /// Emitted when a [`Menu`] has closed.
    ///
    /// [`Menu`]: super::Menu
    #[derive(Clone, Copy, Debug, Signal)]
    pub struct Closed;
}

#[derive(Clone, Debug)]
pub enum Action {
    Enter(String),
    Submit,
    OpenMenu,
    Prev,
    Next,
    CloseSub,
    Close,
}

#[derive(Clone)]
pub enum MenuMessage<Msg> {
    /// Empty message. Only triggers a redraw.
    Empty,
    /// Message targetted at the menu itself.
    Action(Action),
    /// Built-in `Widget` message.
    BuiltinWidget(WidgetMessage),
    /// Custom message for user-defined widgets.
    Custom(Msg),
}

pub type BoxedEntry<Msg> =
    Box<dyn Entry<Message = MenuMessage<Msg>, Menu = Menu<Msg>> + Sync + Send + 'static>;

pub type ViewCallback<Msg> = Box<
    dyn Fn(Vec<WidgetDef<MenuMessage<Msg>>>, &Style) -> WidgetDef<MenuMessage<Msg>> + Sync + Send,
>;

/// Menu internals.
struct Inner<Msg> {
    direction: Direction,
    current_direction: Option<Direction>,
    popup_config: PopupConfig,
    child_popup_config: PopupConfig,
    style: Style,
    entry_style: entry::Style,
    key_config: KeyConfig,
    entries: Arc<Mutex<Vec<BoxedEntry<Msg>>>>,
    entry_indices: HashMap<String, usize>,
    submenu: Option<Box<Menu<Msg>>>,
    submenu_signals: Option<MenuSignals>,
    active_idx: Option<usize>,
    view_callback: Option<ViewCallback<Msg>>,
    emitter: Emitter,
    handle: Option<PopupHandle<MenuMessage<Msg>>>,
}

/// Menu popup's program.
struct MenuProgram<Msg>(WeakMenu<Msg>);

/// Glacier's menu.
///
/// See module level [documentation].
///
/// [documentation]: crate::menu
#[derive(Clone)]
pub struct Menu<Msg> {
    state: Arc<Mutex<Inner<Msg>>>,
}

/// Non owning [`Menu`] handle.
pub struct WeakMenu<Msg>(Weak<Mutex<Inner<Msg>>>);

struct MenuSignals {
    request_close: crate::signal::Handle<signal::RequestClose>,
    closed: crate::signal::Handle<signal::Closed>,
}

/// [`Menu`]'s direction.
///
/// The direction is used to determine anchors and gravities when spawning menus and submenus.
#[derive(Debug, Clone, Copy)]
pub enum Direction {
    DownRight,
    DownLeft,
    UpRight,
    UpLeft,
}

/// [`Menu`]'s popup configuration options.
#[derive(Default, Debug, Clone)]
pub struct PopupConfig {
    pub position: Option<Position>,
    pub anchor: Option<Anchor>,
    pub gravity: Option<Gravity>,
    pub offset: Option<Offset>,
    pub constraints_adj: Option<ConstraintsAdjust>,
}

/// [`Menu`] keyboard configuration.
#[derive(Default, Debug, Clone)]
pub struct KeyConfig {
    pub follow_direction: bool,
    pub next: HashSet<Keysym>,
    pub prev: HashSet<Keysym>,
    pub submit: HashSet<Keysym>,
    pub open_menu: HashSet<Keysym>,
    pub close_menu: HashSet<Keysym>,
    pub close: HashSet<Keysym>,
}

/// [`Menu`] configuration options.
#[derive(Default, Debug, Clone)]
pub struct MenuConfig {
    pub direction: Option<Direction>,
    pub popup_config: Option<PopupConfig>,
    pub child_popup_config: Option<PopupConfig>,
    pub style: Option<Style>,
    pub entry_style: Option<entry::Style>,
    pub key_config: Option<KeyConfig>,
    pub replace_key_config: bool,
}

impl<Msg> Menu<Msg> {
    /// Creates a new menu using the default [`MenuConfig`].
    pub fn new() -> Self {
        Self::with_config(Default::default())
    }

    /// Creates a new menu using a specific [`MenuConfig`].
    pub fn with_config(config: MenuConfig) -> Self {
        let MenuConfig {
            direction,
            popup_config,
            child_popup_config,
            style,
            entry_style,
            key_config,
            replace_key_config,
        } = config;

        let inner = Inner {
            direction: direction.unwrap_or(Direction::DownRight),
            current_direction: None,
            popup_config: popup_config.unwrap_or_default(),
            child_popup_config: child_popup_config.unwrap_or_default(),
            style: style.unwrap_or_else(Self::default_style),
            entry_style: entry_style.unwrap_or_else(entry::default_style),
            key_config: Self::default_key_config(),
            entries: Default::default(),
            entry_indices: Default::default(),
            active_idx: None,
            submenu: None,
            submenu_signals: None,
            view_callback: None,
            emitter: Emitter::default(),
            handle: None,
        };

        let menu = Self {
            state: Arc::new(Mutex::new(inner)),
        };

        if let Some(key_config) = key_config {
            menu.key_config(key_config, replace_key_config)
        } else {
            menu
        }
    }

    /// Sets the menu [`Direction`].
    pub fn direction(self, direction: Direction) -> Self {
        self.state.lock().unwrap().direction = direction;

        self
    }

    /// Sets configuration option for the menu's popup.
    pub fn popup_config(self, config: PopupConfig) -> Self {
        self.state.lock().unwrap().popup_config = config;

        self
    }

    /// Sets configuration option for submenu's popup.
    pub fn child_popup_config(self, config: PopupConfig) -> Self {
        self.state.lock().unwrap().child_popup_config = config;

        self
    }

    /// Sets the menu's [`Style`].
    pub fn style(self, style: Style) -> Self {
        self.state.lock().unwrap().style = style;

        self
    }

    /// Sets the menu entries' [`Style`].
    /// [`Style`]: entry::Style
    pub fn entry_style(self, style: entry::Style) -> Self {
        self.state.lock().unwrap().entry_style = style;

        self
    }

    /// Sets the menu's keyboard config.
    pub fn key_config(self, config: KeyConfig, replace: bool) -> Self {
        let KeyConfig {
            follow_direction,
            next,
            prev,
            submit,
            open_menu,
            close_menu,
            close,
        } = config;

        {
            let mut guard = self.state.lock().unwrap();
            let key_config = &mut guard.key_config;

            if replace {
                if !next.is_empty() {
                    key_config.next.clear()
                }
                if !prev.is_empty() {
                    key_config.prev.clear()
                }
                if !submit.is_empty() {
                    key_config.submit.clear()
                }
                if !open_menu.is_empty() {
                    key_config.open_menu.clear()
                }
                if !close_menu.is_empty() {
                    key_config.close_menu.clear()
                }
                if !close.is_empty() {
                    key_config.close.clear()
                }
            }

            key_config.follow_direction = follow_direction;
            key_config.next = key_config.next.union(&next).cloned().collect();
            key_config.prev = key_config.prev.union(&prev).cloned().collect();
            key_config.submit = key_config.submit.union(&submit).cloned().collect();
            key_config.open_menu = key_config.open_menu.union(&open_menu).cloned().collect();
            key_config.close_menu = key_config.close_menu.union(&close_menu).cloned().collect();
            key_config.close = key_config.close.union(&close).cloned().collect();
        }

        self
    }

    /// Close the menu.
    pub fn close(&self) {
        self.state.lock().unwrap().close();
    }

    /// Create a [`WeakMenu`] pointing to the same object.
    pub fn downgrade(&self) -> WeakMenu<Msg> {
        WeakMenu(Arc::downgrade(&self.state))
    }

    /// Default keyboard configuration for [`Menu`]
    pub fn default_key_config() -> KeyConfig {
        KeyConfig {
            follow_direction: false,
            next: [Keysym::Down].into(),
            prev: [Keysym::Up].into(),
            submit: [Keysym::Return].into(),
            open_menu: [Keysym::Right].into(),
            close_menu: [Keysym::Left].into(),
            close: [Keysym::Escape].into(),
        }
    }

    /// Default [`Menu`] style.
    pub fn default_style() -> Style {
        Style {
            bg_color: Some(color::from_hex("#2b2b2b")),
            width: Some(Length::Fixed(250.)),
            height: None,
            padding: None,
            spacing: Some(1.),
            border: None,
        }
    }
}

impl<Msg> Menu<Msg>
where
    Msg: Clone + Send + 'static,
{
    /// Sets the [`Menu`] entries.
    pub fn entries(self, entries: Vec<BoxedEntry<Msg>>) -> Self {
        let mut entries = entries;
        {
            let mut guard = self.state.lock().unwrap();
            guard.entry_indices.clear();

            for (idx, entry) in entries.iter_mut().enumerate() {
                if entry.key().is_empty() {
                    let mut label = entry.label().to_string();

                    if label.is_empty() {
                        label = "NOLABEL".into()
                    } else {
                        label = label.replace(" ", "-");
                    }

                    let new_key = format!("#{idx}-{label}");
                    entry.set_key(new_key);
                }

                let key = entry.key();

                guard.entry_indices.insert(key.to_string(), idx);
            }

            guard.entries = Arc::new(Mutex::new(entries))
        }

        self
    }

    pub fn view_callback<F>(self, callback: F) -> Self
    where
        F: Fn(Vec<WidgetDef<MenuMessage<Msg>>>, &Style) -> WidgetDef<MenuMessage<Msg>>
            + Send
            + Sync
            + 'static,
    {
        self.state.lock().unwrap().view_callback = Some(Box::new(callback));

        self
    }

    /// Display the [`Menu`].
    #[must_use = "dropping the menu will close it before it's even shown."]
    pub fn show(
        self,
        parent: Parent,
        direction: Option<Direction>,
        overrides: Option<PopupConfig>,
    ) -> Self {
        if let Some(handle) = self.state.lock().unwrap().handle.take() {
            handle.close();
        };

        let overrides = overrides.unwrap_or_default();
        let config = self.state.lock().unwrap().popup_config.clone();
        let fallback_direction = self.state.lock().unwrap().direction;

        let current_direction = direction.unwrap_or(fallback_direction);

        let position = overrides
            .position
            .or(config.position)
            .expect("Menu must have a position.");
        let anchor = overrides
            .anchor
            .or(config.anchor)
            .or(Some(current_direction.to_anchor()));
        let gravity = overrides
            .gravity
            .or(config.gravity)
            .or(Some(current_direction.to_gravity()));
        let offset = overrides.offset.or(config.offset);
        let constraints_adjust = overrides.constraints_adj.or(config.constraints_adj);

        let program = MenuProgram(self.downgrade());

        let handle = popup::new_widget(
            program,
            &parent,
            position,
            anchor,
            gravity,
            offset,
            constraints_adjust,
            false,
            false,
        )
        .expect("Could not create Popup for this menu.");

        handle.on_key_press({
            let weak = self.downgrade();
            move |handle, key, _| {
                let Some(menu) = weak.upgrade() else {
                    return;
                };

                let current_dir = menu.state.lock().unwrap().current_direction;
                let flip_dir = matches!(current_dir, Some(Direction::DownLeft | Direction::UpLeft));

                let KeyConfig {
                    follow_direction,
                    next,
                    prev,
                    submit,
                    mut open_menu,
                    mut close_menu,
                    close,
                } = menu.state.lock().unwrap().key_config.clone();

                if follow_direction && flip_dir {
                    std::mem::swap(&mut open_menu, &mut close_menu);
                }

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
                    menu.emit(signal::RequestClose);
                    return;
                } else {
                    return;
                };

                handle.send_message(action.into());
            }
        });

        self.state.lock().unwrap().current_direction = Some(current_direction);
        self.state.lock().unwrap().handle = Some(handle);

        self
    }

    /// Default [`Menu`] view.
    pub fn default_view(
        entries: Vec<WidgetDef<MenuMessage<Msg>>>,
        style: &Style,
    ) -> WidgetDef<MenuMessage<Msg>> {
        let mut column = Column::new_with_children(entries);
        column.spacing = style.spacing;

        let mut container = Container::new(column);

        container.width = style.width;
        container.height = style.height;
        container.padding = style.padding;
        container.style = Some(container::Style {
            background_color: style.bg_color,
            border: style.border,
            ..Default::default()
        });

        container.into()
    }

    fn refresh_active_idx(&self) {
        let mut state = self.state.lock().unwrap();
        let len = state.entries.lock().unwrap().len();
        if len == 0 {
            state.active_idx = None;
        }
    }

    fn active_idx(&self) -> Option<usize> {
        self.state.lock().unwrap().active_idx
    }

    fn get_entries(&self) -> Arc<Mutex<Vec<BoxedEntry<Msg>>>> {
        self.state.try_lock().unwrap().entries.clone()
    }

    fn index_for(&self, key: String) -> Option<usize> {
        self.state
            .try_lock()
            .unwrap()
            .entry_indices
            .get(&key)
            .cloned()
    }

    fn open_submenu(&self) {
        let Some(idx) = self.active_idx() else {
            return;
        };

        let entries = self.get_entries();
        let (key, mut submenu) = {
            let entries_guard = entries.lock().unwrap();

            let Some(entry) = entries_guard.get(idx) else {
                return;
            };

            if entry.disabled() {
                return;
            }

            let key = entry.key();
            if key.is_empty() {
                tracing::error!("Cannot open submenu for key-less entries.");
                return;
            }

            let Some(submenu) = entry.open_menu() else {
                return;
            };

            (key.to_string(), submenu)
        };

        self.close_submenu();

        let parent = self
            .state
            .lock()
            .unwrap()
            .handle
            .as_ref()
            .map(AsParent::as_parent)
            .expect("menu should have a handle at this point.");

        let direction = self.state.lock().unwrap().current_direction;
        let mut child_popup_config = self.state.lock().unwrap().child_popup_config.clone();

        submenu = submenu.popup_config(child_popup_config.clone());
        submenu = submenu.child_popup_config(child_popup_config.clone());
        submenu = submenu.style(self.state.lock().unwrap().style.clone());
        submenu = submenu.entry_style(self.state.lock().unwrap().entry_style.clone());
        submenu = submenu.key_config(self.state.lock().unwrap().key_config.clone(), true);

        child_popup_config.position = Some(Position::at_widget(key));

        let mut submenu = submenu.show(parent, direction, Some(child_popup_config));

        let request_close = submenu.connect({
            let weak = self.downgrade();
            move |_: signal::RequestClose| {
                let Some(menu) = weak.upgrade() else {
                    return crate::signal::HandlerPolicy::Discard;
                };
                if let Some(handle) = menu.state.lock().unwrap().handle.as_mut() {
                    handle.send_message(Action::CloseSub.into());
                }
                crate::signal::HandlerPolicy::Keep
            }
        });

        let closed = submenu.connect({
            let weak = self.downgrade();
            move |_: signal::Closed| {
                let Some(menu) = weak.upgrade() else {
                    return crate::signal::HandlerPolicy::Discard;
                };

                if let Some(handle) = menu.state.lock().unwrap().handle.as_mut() {
                    handle.send_message(Action::Close.into());
                }
                crate::signal::HandlerPolicy::Discard
            }
        });

        self.state.lock().unwrap().submenu = Some(Box::new(submenu));
        self.state.lock().unwrap().submenu_signals = Some(MenuSignals {
            request_close,
            closed,
        });
    }

    fn close_submenu(&self) {
        let submenu = self.state.lock().unwrap().submenu.take();
        let Some(mut submenu) = submenu else {
            return;
        };

        let submenu_signals = self.state.lock().unwrap().submenu_signals.take();
        if let Some(submenu_signals) = submenu_signals {
            let MenuSignals {
                request_close,
                closed,
            } = submenu_signals;

            submenu.disconnect(request_close);
            submenu.disconnect(closed);
        }

        submenu.close();
    }

    fn deactivate(&self) {
        let active_idx = self.active_idx();

        if let Some(idx) = active_idx {
            let entries = self.get_entries();

            if let Some(entry) = entries.lock().unwrap().get_mut(idx) {
                entry.deactivate()
            }
        }

        self.close_submenu();
        self.state.lock().unwrap().active_idx = None;
    }

    fn can_activate(&self, idx: usize) -> bool {
        let entries = self.get_entries();

        let not_disabled = entries.lock().unwrap().get(idx).map(|i| !i.disabled());

        not_disabled.unwrap_or(false)
    }

    fn activate(&self, idx: usize, hover: bool) -> Option<MenuMessage<Msg>> {
        if !self.can_activate(idx) {
            return None;
        }

        let active_idx = self.active_idx();
        if active_idx != Some(idx) {
            self.deactivate();
        }

        self.state.lock().unwrap().active_idx = Some(idx);
        let entries = self.get_entries();
        entries
            .lock()
            .unwrap()
            .get_mut(idx)
            .and_then(|entry| entry.activate(hover))
    }

    fn next(&self) -> Option<MenuMessage<Msg>> {
        self.refresh_active_idx();

        let mut to_activate = None;

        if let Some(idx) = self.active_idx() {
            let entries = self.get_entries();
            let entries_lock = entries.lock().unwrap();

            to_activate = entries_lock
                .iter()
                .enumerate()
                .skip(idx + 1)
                .find(|(_, entry)| !entry.disabled())
                .map(|(idx, _)| idx);
        }

        if to_activate.is_none() {
            let entries = self.get_entries();
            let entries_lock = entries.lock().unwrap();

            to_activate = entries_lock
                .iter()
                .enumerate()
                .find(|(_, entry)| !entry.disabled())
                .map(|(idx, _)| idx);
        }

        if let Some(idx) = to_activate {
            return self.activate(idx, false);
        }

        None
    }

    fn prev(&self) -> Option<MenuMessage<Msg>> {
        self.refresh_active_idx();

        let mut to_activate = None;

        if let Some(idx) = self.active_idx() {
            let entries = self.get_entries();
            let entries_lock = entries.lock().unwrap();
            to_activate = entries_lock
                .iter()
                .enumerate()
                .take(idx)
                .rev()
                .find(|(_, entry)| !entry.disabled())
                .map(|(idx, _)| idx);
        }

        if to_activate.is_none() {
            let entries = self.get_entries();
            let entries_lock = entries.lock().unwrap();

            to_activate = entries_lock
                .iter()
                .enumerate()
                .rev()
                .find(|(_, entry)| !entry.disabled())
                .map(|(idx, _)| idx);
        }

        if let Some(idx) = to_activate {
            return self.activate(idx, false);
        }

        None
    }

    fn submit(&self) -> Option<MenuMessage<Msg>> {
        let idx = self.active_idx()?;

        let entries = self.get_entries();

        entries
            .lock()
            .unwrap()
            .get(idx)
            .and_then(|entry| entry.submit())
    }
}

impl<Msg> WeakMenu<Msg> {
    /// Attempts to upgrade to an owning [`Menu`].
    ///
    /// Returns [`None`] if the `Menu` has been dropped.
    pub fn upgrade(&self) -> Option<Menu<Msg>> {
        self.0.upgrade().map(|state| Menu { state })
    }
}

impl<Msg> Inner<Msg> {
    fn close(&mut self) {
        if let Some(handle) = self.handle.take() {
            self.emitter.emit(signal::Closing);
            handle.close();
            self.emitter.emit(signal::Closed);
        }
    }
}

impl<Msg> MenuProgram<Msg>
where
    Msg: Clone,
{
    fn view_entry(
        entry: &BoxedEntry<Msg>,
        active: bool,
        style: &entry::Style,
    ) -> Option<WidgetDef<MenuMessage<Msg>>> {
        let child = entry.view(active, style)?;

        let mut marea = MouseArea::new(child);

        if !entry.disabled() {
            marea = marea.on_enter(Action::Enter(entry.key().to_string()).into());
            marea = marea.on_release(Action::Submit.into());
        }

        Some(Container::new(marea).id(entry.key()).into())
    }

    fn view_entries(state: &Inner<Msg>) -> Vec<WidgetDef<MenuMessage<Msg>>> {
        let active_idx = state.active_idx;
        let entry_style = &state.entry_style;

        state
            .entries
            .lock()
            .unwrap()
            .iter()
            .enumerate()
            .filter_map(|(idx, entry)| {
                Self::view_entry(entry, active_idx == Some(idx), entry_style)
            })
            .collect()
    }

    fn update_entries(
        entries: Arc<Mutex<Vec<BoxedEntry<Msg>>>>,
        msg: MenuMessage<Msg>,
        parent: Option<Parent>,
    ) {
        for entry in entries.lock().unwrap().iter_mut() {
            entry.update(msg.clone(), parent);
        }
    }
}

impl<Msg> Program for MenuProgram<Msg>
where
    Msg: Clone + Send + 'static,
{
    type Message = MenuMessage<Msg>;

    fn view(&self) -> snowcap_api::widget::WidgetDef<Self::Message> {
        let Some(menu) = self.0.upgrade() else {
            return Column::new()
                .width(Length::Fixed(1.))
                .height(Length::Fixed(1.))
                .into();
        };

        let state = menu.state.lock().unwrap();
        let children = Self::view_entries(&state);

        if let Some(callback) = &state.view_callback {
            callback(children, &state.style)
        } else {
            Menu::default_view(children, &state.style)
        }
    }

    fn update(&mut self, msg: Self::Message) {
        let Some(menu) = self.0.upgrade() else {
            return;
        };

        let mut next_msg = Some(msg);

        let parent = menu
            .state
            .lock()
            .unwrap()
            .handle
            .as_ref()
            .map(AsParent::as_parent);

        while let Some(msg) = next_msg {
            next_msg = match msg {
                Self::Message::Empty => None,
                Self::Message::Action(Action::Next) => menu.next(),
                Self::Message::Action(Action::Prev) => menu.prev(),
                Self::Message::Action(Action::Enter(key)) => {
                    if let Some(idx) = menu.index_for(key) {
                        menu.activate(idx, true)
                    } else {
                        None
                    }
                }
                Self::Message::Action(Action::Submit) => menu.submit(),
                Self::Message::Action(Action::OpenMenu) => {
                    menu.open_submenu();
                    None
                }
                Self::Message::Action(Action::CloseSub) => {
                    menu.close_submenu();
                    None
                }
                Self::Message::Action(Action::Close) => {
                    menu.close();
                    return;
                }
                _ => {
                    let entries = menu.get_entries();
                    Self::update_entries(entries, msg, parent);
                    None
                }
            };
        }
    }
}

impl Direction {
    fn to_anchor(self) -> Anchor {
        match self {
            Self::DownLeft => Anchor::TopLeft,
            Self::DownRight => Anchor::TopRight,
            Self::UpLeft => Anchor::BottomLeft,
            Self::UpRight => Anchor::BottomRight,
        }
    }

    fn to_gravity(self) -> Gravity {
        match self {
            Self::DownLeft => Gravity::BottomLeft,
            Self::DownRight => Gravity::BottomRight,
            Self::UpLeft => Gravity::TopLeft,
            Self::UpRight => Gravity::TopRight,
        }
    }
}

impl PopupConfig {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn position(self, position: Position) -> Self {
        Self {
            position: Some(position),
            ..self
        }
    }

    pub fn anchor(self, anchor: Anchor) -> Self {
        Self {
            anchor: Some(anchor),
            ..self
        }
    }

    pub fn gravity(self, gravity: Gravity) -> Self {
        Self {
            gravity: Some(gravity),
            ..self
        }
    }

    pub fn offset(self, offset: Offset) -> Self {
        Self {
            offset: Some(offset),
            ..self
        }
    }

    pub fn constraint_adjust(self, constraints_adjust: ConstraintsAdjust) -> Self {
        Self {
            constraints_adj: Some(constraints_adjust),
            ..self
        }
    }
}

impl KeyConfig {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn follow_direction(self, follow: bool) -> Self {
        Self {
            follow_direction: follow,
            ..self
        }
    }

    pub fn next<T>(self, iter: T) -> Self
    where
        T: IntoIterator<Item = Keysym>,
    {
        Self {
            next: HashSet::from_iter(iter),
            ..self
        }
    }

    pub fn prev<T>(self, iter: T) -> Self
    where
        T: IntoIterator<Item = Keysym>,
    {
        Self {
            prev: HashSet::from_iter(iter),
            ..self
        }
    }

    pub fn submit<T>(self, iter: T) -> Self
    where
        T: IntoIterator<Item = Keysym>,
    {
        Self {
            submit: HashSet::from_iter(iter),
            ..self
        }
    }

    pub fn open_menu<T>(self, iter: T) -> Self
    where
        T: IntoIterator<Item = Keysym>,
    {
        Self {
            open_menu: HashSet::from_iter(iter),
            ..self
        }
    }

    pub fn close_menu<T>(self, iter: T) -> Self
    where
        T: IntoIterator<Item = Keysym>,
    {
        Self {
            close_menu: HashSet::from_iter(iter),
            ..self
        }
    }

    pub fn close<T>(self, iter: T) -> Self
    where
        T: IntoIterator<Item = Keysym>,
    {
        Self {
            close: HashSet::from_iter(iter),
            ..self
        }
    }
}

impl<Msg> WithEmitter for Menu<Msg> {
    fn with_emitter(&self) -> Emitter {
        self.state.lock().unwrap().emitter.clone()
    }
}

impl<Msg> Default for Menu<Msg>
where
    Msg: Clone + Send + 'static,
{
    fn default() -> Self {
        Self::new()
    }
}

impl<Msg> Drop for Inner<Msg> {
    fn drop(&mut self) {
        self.close()
    }
}

impl<Msg> From<WidgetMessage> for MenuMessage<Msg> {
    fn from(value: WidgetMessage) -> Self {
        if let WidgetMessage::Operation(_oper) = value {
            Self::Empty
        } else {
            Self::BuiltinWidget(value)
        }
    }
}

impl<Msg> From<MenuMessage<Msg>> for Option<WidgetMessage> {
    fn from(value: MenuMessage<Msg>) -> Self {
        match value {
            MenuMessage::BuiltinWidget(w) => Some(w),
            _ => None,
        }
    }
}

impl<Msg> From<Action> for MenuMessage<Msg> {
    fn from(value: Action) -> Self {
        Self::Action(value)
    }
}

#[macro_export]
macro_rules! menu_entries {
    () => [
        std::vec::Vec::new()
    ];
    ($($entry:expr),+ $(,)?) => [
        vec![
            $(Box::new($child)),*
        ]
    ];
}

pub use menu_entries as entries;
