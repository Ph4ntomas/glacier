//! [SysTray]'s style.
//!
//! [SysTray]: super
use snowcap_api::widget::{Border, Color, Padding};

/// Style for [`SysTray`]'s icons.
///
/// [`SysTray`]: super::SysTray
#[derive(Debug, Default, Clone)]
pub struct IconStyle {
    /// Background color.
    pub bg_color: Option<Color>,
    /// Border surrounding the icon.
    pub border: Option<Border>,
    /// Padding surrounding the icon.
    pub padding: Option<Padding>,
}

/// [`SysTray`]'s style.
///
/// [`SysTray`]: super::SysTray
#[derive(Debug, Default, Clone)]
pub struct Style {
    /// Background color for the SysTray as a whole.
    pub bg_color: Option<Color>,
    /// Border around the SysTray
    pub border: Option<Border>,
    /// Space between SysTray's icons.
    pub spacing: Option<f32>,
    /// Padding around the icon list.
    pub padding: Option<Padding>,
    /// Style to used when a SysTray icon is active.
    pub active: Option<IconStyle>,
    /// Style to used when a SysTray icon is hovered.
    pub hovered: Option<IconStyle>,
    /// Style to used when a SysTray icon is both active and hovered.
    pub active_hovered: Option<IconStyle>,
    /// Fallback Style to use for SysTray's icons.
    pub default: IconStyle,
}

/// [`SysTray`]'s default Style.
///
/// [`SysTray`]: super::SysTray
pub fn default_style() -> Style {
    Style::new().spacing(1.).icon_padding(Padding {
        top: 2.,
        right: 2.,
        bottom: 2.,
        left: 2.,
    })
}

impl Style {
    /// Create a new SysTray's style.
    pub fn new() -> Self {
        Self::default()
    }

    /// Sets background color for the SysTray as a whole.
    pub fn bg_color(self, bg_color: Color) -> Self {
        Self {
            bg_color: Some(bg_color),
            ..self
        }
    }

    /// Sets the border around the SysTray
    pub fn border(self, border: Border) -> Self {
        Self {
            border: Some(border),
            ..self
        }
    }

    /// Sets the space between SysTray's icons.
    pub fn spacing(self, spacing: f32) -> Self {
        Self {
            spacing: Some(spacing),
            ..self
        }
    }

    /// Sets padding around the icon list.
    pub fn padding(self, padding: Padding) -> Self {
        Self {
            padding: Some(padding),
            ..self
        }
    }

    /// Sets the [IconStyle] to used when a SysTray icon is active.
    pub fn active(self, active: IconStyle) -> Self {
        Self {
            active: Some(active),
            ..self
        }
    }

    /// Sets the [IconStyle] to used when a SysTray icon is hovered.
    pub fn hovered(self, hovered: IconStyle) -> Self {
        Self {
            hovered: Some(hovered),
            ..self
        }
    }

    /// Sets the [IconStyle] to used when a SysTray icon is both active and hovered.
    pub fn active_hovered(self, style: IconStyle) -> Self {
        Self {
            active_hovered: Some(style),
            ..self
        }
    }

    /// Sets the [IconStyle] to used as a fallback, or when the icon is neither active nor hovered.
    pub fn icon_default(self, style: IconStyle) -> Self {
        Self {
            default: style,
            ..self
        }
    }

    /// Sets the default background color for icons.
    pub fn icon_bg_color(self, color: Color) -> Self {
        let default = self.default;

        Self {
            default: IconStyle {
                bg_color: Some(color),
                ..default
            },
            ..self
        }
    }

    /// Sets the default border surrounding icons.
    pub fn icon_border(self, border: Border) -> Self {
        let default = self.default;

        Self {
            default: IconStyle {
                border: Some(border),
                ..default
            },
            ..self
        }
    }

    /// Sets the default padding surrounding the icon.
    pub fn icon_padding(self, padding: Padding) -> Self {
        let default = self.default;

        Self {
            default: IconStyle {
                padding: Some(padding),
                ..default
            },
            ..self
        }
    }

    fn get_active_style(&self) -> IconStyle {
        let Some(style) = self.active.clone() else {
            return self.default.clone();
        };

        IconStyle {
            bg_color: style.bg_color.or(self.default.bg_color),
            border: style.border.or(self.default.border),
            padding: style.padding.or(self.default.padding),
        }
    }

    fn get_hovered_style(&self) -> IconStyle {
        let Some(style) = self.hovered.clone() else {
            return self.default.clone();
        };

        IconStyle {
            bg_color: style.bg_color.or(self.default.bg_color),
            border: style.border.or(self.default.border),
            padding: style.padding.or(self.default.padding),
        }
    }

    fn get_active_hovered_style(&self) -> IconStyle {
        let active = self.active.clone().unwrap_or_default();
        let hovered = self.hovered.clone().unwrap_or_default();
        let active_hovered = self.active_hovered.clone().unwrap_or_default();

        let bg_color = active_hovered
            .bg_color
            .or(active.bg_color)
            .or(hovered.bg_color)
            .or(self.default.bg_color);

        let border = active_hovered
            .border
            .or(active.border)
            .or(hovered.border)
            .or(self.default.border);

        let padding = active_hovered
            .padding
            .or(active.padding)
            .or(hovered.padding)
            .or(self.default.padding);

        IconStyle {
            bg_color,
            border,
            padding,
        }
    }

    /// Get an [`IconStyle`] based on the current icon status.
    pub fn get_icon_style(&self, active: bool, hovered: bool) -> IconStyle {
        if active && hovered {
            self.get_active_hovered_style()
        } else if active {
            self.get_active_style()
        } else if hovered {
            self.get_hovered_style()
        } else {
            self.default.clone()
        }
    }
}

impl IconStyle {
    /// Create a new [`IconStyle`], with default values.
    pub fn new() -> Self {
        Self::default()
    }

    /// Sets the background color.
    pub fn bg_color(self, color: Color) -> Self {
        Self {
            bg_color: Some(color),
            ..self
        }
    }

    /// Sets the border surrounding the icon.
    pub fn border(self, border: Border) -> Self {
        Self {
            border: Some(border),
            ..self
        }
    }

    /// Sets the padding surrounding the icon.
    pub fn padding(self, padding: Padding) -> Self {
        Self {
            padding: Some(padding),
            ..self
        }
    }
}
