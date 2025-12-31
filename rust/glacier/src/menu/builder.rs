//! Build [`Menu`].
//!
//! [`Builder`] allow creating [`Menu`]s using [`SimpleEntry`], [`SimpleMenu`] and [`Separator`].
//! Their goal is to provide a easier interface to work with when programmatically creating menus.

use crate::menu::{
    BoxedEntry, Direction, KeyConfig, Menu, MenuConfig, MenuMessage, PopupConfig, Style,
    entry::{self, Separator, SimpleEntry, SimpleMenu},
};

/// Return a new [`Builder`]
pub fn builder<Msg>() -> Builder<Msg> {
    Builder::new()
}

/// Helper type to build [`Menu`]s.
pub struct Builder<Msg> {
    config: MenuConfig,
    entries: Vec<BoxedEntry<Msg>>,
}

impl<Msg> Builder<Msg> {
    /// Create a new [`Builder`].
    pub fn new() -> Self {
        Self {
            config: MenuConfig {
                direction: None,
                popup_config: None,
                child_popup_config: None,
                style: None,
                entry_style: None,
                key_config: None,
                replace_key_config: false,
            },
            entries: Default::default(),
        }
    }

    /// Sets the menu [`Direction`].
    pub fn with_direction(self, direction: Direction) -> Self {
        Self {
            config: MenuConfig {
                direction: Some(direction),
                ..self.config
            },
            ..self
        }
    }

    /// Sets the menu's [`PopupConfig`].
    pub fn with_popup_config(self, config: PopupConfig) -> Self {
        Self {
            config: MenuConfig {
                popup_config: Some(config),
                ..self.config
            },
            ..self
        }
    }

    /// Sets submenu's [`PopupConfig`].
    pub fn with_child_popup_config(self, config: PopupConfig) -> Self {
        Self {
            config: MenuConfig {
                child_popup_config: Some(config),
                ..self.config
            },
            ..self
        }
    }

    /// Sets the menu's [`Style`].
    pub fn with_style(self, style: Style) -> Self {
        Self {
            config: MenuConfig {
                style: Some(style),
                ..self.config
            },
            ..self
        }
    }

    /// Sets menu's entries [`Style`].
    ///
    /// [`Style`]: entry::Style
    pub fn with_entry_style(self, style: entry::Style) -> Self {
        Self {
            config: MenuConfig {
                entry_style: Some(style),
                ..self.config
            },
            ..self
        }
    }

    /// Sets the menu's [`KeyConfig`].
    pub fn with_key_config(self, config: KeyConfig, replace: bool) -> Self {
        Self {
            config: MenuConfig {
                key_config: Some(config),
                replace_key_config: replace,
                ..self.config
            },
            ..self
        }
    }
}

impl<Msg> Builder<Msg>
where
    Msg: Clone + Sync + Send + 'static,
{
    /// Add an entry to the [`Menu`] being build.
    pub fn add_entry<F>(self, label: impl ToString, on_submit: F) -> Self
    where
        F: Fn() -> Option<MenuMessage<Msg>> + Sync + Send + 'static,
    {
        let Self { mut entries, .. } = self;

        entries.push(Box::new(SimpleEntry::new(label, on_submit)));

        Self { entries, ..self }
    }

    /// Add a disabled entry to the [`Menu`] being build.
    pub fn add_disabled(self, label: impl ToString) -> Self {
        let Self { mut entries, .. } = self;

        entries.push(Box::new(SimpleEntry::new_disabled(label)));

        Self { entries, ..self }
    }

    /// Add a menu entry to the [`Menu`] being build.
    pub fn add_menu(self, label: impl ToString, menu: Menu<Msg>) -> Self {
        let Self { mut entries, .. } = self;

        entries.push(Box::new(SimpleMenu::new(label, move || Some(menu.clone()))));

        Self { entries, ..self }
    }

    /// Add a disabled menu entry to the [`Menu`] being build.
    pub fn add_disabled_menu(self, label: impl ToString) -> Self {
        let Self { mut entries, .. } = self;

        entries.push(Box::new(SimpleMenu::new_disabled(label)));

        Self { entries, ..self }
    }

    /// Add a separator to the [`Menu`] being build.
    pub fn add_separator(self) -> Self {
        let Self { mut entries, .. } = self;

        entries.push(Box::new(Separator::new()));

        Self { entries, ..self }
    }

    /// Build a [`Menu`] using the current configuration.
    pub fn build(self) -> Menu<Msg> {
        Menu::with_config(self.config).entries(self.entries)
    }
}

impl<Msg> Default for Builder<Msg> {
    fn default() -> Self {
        Self::new()
    }
}
