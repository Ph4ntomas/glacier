//! Entry's style.

use snowcap_api::widget::{Border, Color, Length, Padding, font::Font};

/// Appearance of an [`Entry`].
///
/// [`Entry`]: crate::menu::entry::Entry
#[derive(Default, Debug, Clone)]
pub struct Style {
    /// Entries font size.
    pub font_size: Option<f32>,
    /// Entries font.
    pub font: Option<Font>,
    /// Default entry style.
    pub default: EntryStyle,
    /// Style overrides for active entries.
    pub active: Option<EntryStyle>,
    /// Style overrides for disabled entries.
    pub disabled: Option<EntryStyle>,
    /// Menu indicator style.
    pub menu_indicator: Option<MenuIndicatorStyle>,
    /// Separators style.
    pub separator: Option<SeparatorStyle>,
}

/// Appearance of an menu's [`Entry`].
///
/// [`Entry`]: crate::menu::entry::Entry
#[derive(Default, Debug, Clone)]
pub struct EntryStyle {
    /// Entries foreground color.
    pub fg_color: Option<Color>,
    /// Entries background color.
    pub bg_color: Option<Color>,
    /// Entries height.
    pub height: Option<Length>,
    /// Entries padding.
    pub padding: Option<Padding>,
    /// Entries border.
    pub border: Option<Border>,
}

/// Appearance of an menu's [`Entry`]'s submenu icon.
///
/// [`Entry`]: crate::menu::entry::Entry
#[derive(Default, Debug, Clone)]
pub struct MenuIndicatorStyle {
    /// Menu indicator width.
    pub width: Option<Length>,
    /// Menu indicator height.
    pub height: Option<Length>,
    /// Menu indicator color.
    pub color: Option<Color>,
}

/// Appearance of a menu's [`Entry`] acting as a separator.
///
/// [`Entry`]: crate::menu::entry::Entry
#[derive(Default, Debug, Clone)]
pub struct SeparatorStyle {
    /// Separators foreground color.
    pub fg_color: Option<Color>,
    /// Separators background color.
    pub bg_color: Option<Color>,
    /// Separators height.
    pub height: Option<Length>,
    /// Separators padding.
    pub padding: Option<Padding>,
    /// Separators thickness.
    pub thickness: Option<f32>,
}

impl Style {
    /// Create a new [`Style`] with default values.
    pub fn new() -> Self {
        Self::default()
    }

    /// Sets entries font size.
    pub fn font_size(self, size: f32) -> Self {
        Self {
            font_size: Some(size),
            ..self
        }
    }

    /// Sets entries font.
    pub fn font(self, font: Font) -> Self {
        Self {
            font: Some(font),
            ..self
        }
    }

    /// Sets default entry style.
    pub fn default_style(self, style: EntryStyle) -> Self {
        Self {
            default: style,
            ..self
        }
    }

    /// Sets style overrides for active entries.
    pub fn active_style(self, style: EntryStyle) -> Self {
        Self {
            active: Some(style),
            ..self
        }
    }

    /// Sets style overrides for disabled entries.
    pub fn disabled_style(self, style: EntryStyle) -> Self {
        Self {
            disabled: Some(style),
            ..self
        }
    }

    /// Sets menu indicator style.
    pub fn menu_indicator(self, style: MenuIndicatorStyle) -> Self {
        Self {
            menu_indicator: Some(style),
            ..self
        }
    }

    /// Sets separators style.
    pub fn separator(self, style: SeparatorStyle) -> Self {
        Self {
            separator: Some(style),
            ..self
        }
    }

    /// Sets default entry foreground color.
    pub fn fg_color(self, color: Color) -> Self {
        let Self { default, .. } = self;

        Self {
            default: default.fg_color(color),
            ..self
        }
    }

    /// Sets default entry background color.
    pub fn bg_color(self, color: Color) -> Self {
        let Self { default, .. } = self;

        Self {
            default: default.bg_color(color),
            ..self
        }
    }

    /// Sets default height.
    pub fn height(self, height: Length) -> Self {
        let Self { default, .. } = self;

        Self {
            default: default.height(height),
            ..self
        }
    }

    /// Sets default padding.
    pub fn padding(self, padding: Padding) -> Self {
        let Self { default, .. } = self;

        Self {
            default: default.padding(padding),
            ..self
        }
    }

    /// Sets default entry border.
    pub fn border(self, border: Border) -> Self {
        let Self { default, .. } = self;

        Self {
            default: default.border(border),
            ..self
        }
    }
}

impl EntryStyle {
    /// Create a new [`EntryStyle`] with default values.
    pub fn new() -> Self {
        Self::default()
    }

    /// Sets entries foreground color.
    pub fn fg_color(self, color: Color) -> Self {
        Self {
            fg_color: Some(color),
            ..self
        }
    }

    /// Sets entries background color.
    pub fn bg_color(self, color: Color) -> Self {
        Self {
            bg_color: Some(color),
            ..self
        }
    }

    /// Sets entries height.
    pub fn height(self, height: Length) -> Self {
        Self {
            height: Some(height),
            ..self
        }
    }

    /// Sets entries padding.
    pub fn padding(self, padding: Padding) -> Self {
        Self {
            padding: Some(padding),
            ..self
        }
    }

    /// Sets entries border.
    pub fn border(self, border: Border) -> Self {
        Self {
            border: Some(border),
            ..self
        }
    }
}

impl MenuIndicatorStyle {
    /// Create a new [`MenuIndicatorStyle`] with default values.
    pub fn new() -> Self {
        Self::default()
    }

    /// Sets the menu indicator width.
    pub fn width(self, width: Length) -> Self {
        Self {
            width: Some(width),
            ..self
        }
    }

    /// Sets the menu indicator height.
    pub fn height(self, height: Length) -> Self {
        Self {
            height: Some(height),
            ..self
        }
    }

    /// Sets the menu indicator color.
    pub fn color(self, color: Color) -> Self {
        Self {
            color: Some(color),
            ..self
        }
    }
}

impl SeparatorStyle {
    /// Create a new [`SeparatorStyle`] with default values.
    pub fn new() -> Self {
        Self::default()
    }

    /// Sets separators foreground color.
    pub fn fg_color(self, color: Color) -> Self {
        Self {
            fg_color: Some(color),
            ..self
        }
    }

    /// Sets separators background color.
    pub fn bg_color(self, color: Color) -> Self {
        Self {
            bg_color: Some(color),
            ..self
        }
    }

    /// Sets separators height.
    pub fn height(self, height: Length) -> Self {
        Self {
            height: Some(height),
            ..self
        }
    }

    /// Sets separators padding.
    pub fn padding(self, padding: Padding) -> Self {
        Self {
            padding: Some(padding),
            ..self
        }
    }

    /// Sets separators thickness.
    pub fn thickness(self, thickness: f32) -> Self {
        Self {
            thickness: Some(thickness),
            ..self
        }
    }
}
