//! [`TagList`] widget styling.
//!
//! [`TagList`]: super::TagList

use std::sync::Arc;

use snowcap_api::widget::{Border, Color, Padding, container, font::Font, text};

/// Appearance of a single [`Tag`]
///
/// [`Tag`]: super::Tag
#[derive(Default, Clone)]
pub struct TagStyle {
    /// Background [`Color`].
    pub bg_color: Option<Color>,
    /// Text [`Color`].
    pub fg_color: Option<Color>,
    /// Text [`Font`].
    pub font: Option<Font>,
    /// Text size, in pixels.
    pub pixels: Option<f32>,
    /// [`Border`] around the text container.
    pub border: Option<Border>,
    /// [`Padding`] arount the text.
    pub padding: Option<Padding>,
}

/// Appearance of a [`TagList`]
///
/// [`TagList`]: super::TagList
#[derive(Default, Clone)]
pub struct Style {
    /// Default [`TagStyle`].
    pub default: TagStyle,
    /// Overrides for rendering active [`Tag`].
    ///
    /// [`Tag`]: super::Tag
    pub active: Option<TagStyle>,
    /// Overrides for rendering inactive [`Tag`].
    ///
    /// [`Tag`]: super::Tag
    pub inactive: Option<TagStyle>,
    /// Spacing between [`Tag`].
    ///
    /// [`Tag`]: super::Tag
    pub spacing: Option<f32>,
    /// Transform to apply to hovered [`TagStyle`].
    pub hover_transform: Option<Arc<dyn Fn(TagStyle) -> TagStyle + Send + Sync>>,
}

/// Built-in [hover_transform].
///
/// [hover_transform]: Style::hover_transform
pub fn brighten_background(amount: f32) -> impl Fn(TagStyle) -> TagStyle {
    use snowcap_api::widget::Color;
    move |style| {
        let color = if let Some(Color {
            red,
            green,
            blue,
            alpha,
        }) = style.bg_color
        {
            let red = (red * amount).clamp(0.0, 1.0);
            let green = (green * amount).clamp(0.0, 1.0);
            let blue = (blue * amount).clamp(0.0, 1.0);

            Some(Color {
                red,
                green,
                blue,
                alpha,
            })
        } else {
            None
        };

        TagStyle {
            bg_color: color,
            ..style
        }
    }
}

impl Style {
    /// Create a new [`Style`] with default values.
    pub fn new() -> Self {
        Self::default()
    }

    /// Sets the default background [`Color`].
    pub fn bg_color(self, bg_color: Color) -> Self {
        Self {
            default: self.default.bg_color(bg_color),
            ..self
        }
    }

    /// Sets the default text [`Color`].
    pub fn fg_color(self, fg_color: Color) -> Self {
        Self {
            default: self.default.fg_color(fg_color),
            ..self
        }
    }

    /// Sets the text [`Font`].
    pub fn font(self, font: Font) -> Self {
        Self {
            default: self.default.font(font),
            ..self
        }
    }

    /// Sets the [`Border`] used to render the list.
    pub fn border(self, border: Border) -> Self {
        Self {
            default: self.default.border(border),
            ..self
        }
    }

    /// Sets the list [`Padding`].
    pub fn padding(self, padding: Padding) -> Self {
        Self {
            default: self.default.padding(padding),
            ..self
        }
    }

    /// Sets the spacing between [`Tag`]s.
    ///
    /// [`Tag`]: super::Tag
    pub fn spacing(self, spacing: f32) -> Self {
        Self {
            spacing: Some(spacing),
            ..self
        }
    }

    /// Sets override [`TagStyle`] for active [`Tag`]s.
    ///
    /// [`Tag`]: super::Tag
    pub fn active(self, active: TagStyle) -> Self {
        Self {
            active: Some(active),
            ..self
        }
    }

    /// Sets override [`TagStyle`] for inactive [`Tag`]s.
    ///
    /// [`Tag`]: super::Tag
    pub fn inactive(self, inactive: TagStyle) -> Self {
        Self {
            inactive: Some(inactive),
            ..self
        }
    }

    /// Sets the callback to use to modify the [`TagStyle`] for hovered [`Tag`]s
    ///
    /// [`Tag`]: super::Tag
    pub fn hover_transform<F>(self, callback: F) -> Self
    where
        F: Fn(TagStyle) -> TagStyle + Send + Sync + 'static,
    {
        Self {
            hover_transform: Some(Arc::new(callback)),
            ..self
        }
    }

    /// Return the [`TagStyle`] to display a [`Tag`], based on its activation statue.
    ///
    /// The returned `TagStyle` uses either [`Style::active`] or [`Style::inactive`], overriding
    /// empty field with the one from [`Style::default`].
    ///
    /// [`Tag`]: super::Tag
    pub fn get(&self, active: bool) -> TagStyle {
        let style = if active { &self.active } else { &self.inactive };

        if let Some(style) = style {
            style.apply_default(&self.default)
        } else {
            self.default.clone()
        }
    }
}

impl TagStyle {
    /// Create a new [`TagStyle`]
    pub fn new() -> Self {
        Self::default()
    }

    /// Sets the background [`Color`].
    pub fn bg_color(self, bg_color: Color) -> Self {
        Self {
            bg_color: Some(bg_color),
            ..self
        }
    }

    /// Sets the foreground [`Color`].
    pub fn fg_color(self, fg_color: Color) -> Self {
        Self {
            fg_color: Some(fg_color),
            ..self
        }
    }

    /// Sets the text [`Font`].
    pub fn font(self, font: Font) -> Self {
        Self {
            font: Some(font),
            ..self
        }
    }

    /// Sets the [`Border`] to use when rendering
    ///
    /// [`Tag`]: super::Tag
    pub fn border(self, border: Border) -> Self {
        Self {
            border: Some(border),
            ..self
        }
    }

    /// Sets the [`Padding`] to use when rendering.
    pub fn padding(self, padding: Padding) -> Self {
        Self {
            padding: Some(padding),
            ..self
        }
    }

    /// Builds a new [`TagStyle`] by filling empty fields with the one from `default`.
    pub fn apply_default(&self, default: &TagStyle) -> TagStyle {
        let TagStyle {
            bg_color,
            fg_color,
            font,
            pixels,
            border,
            padding,
        } = self.clone();

        TagStyle {
            bg_color: bg_color.or(default.bg_color),
            fg_color: fg_color.or(default.fg_color),
            font: font.or_else(|| default.font.clone()),
            pixels: pixels.or(default.pixels),
            border: border.or(default.border),
            padding: padding.or(default.padding),
        }
    }
}

impl From<TagStyle> for container::Style {
    fn from(value: TagStyle) -> Self {
        Self {
            text_color: value.fg_color,
            background: value.bg_color.map(From::from),
            border: value.border,
        }
    }
}

impl From<TagStyle> for text::Style {
    fn from(value: TagStyle) -> Self {
        let TagStyle {
            fg_color: color,
            font,
            pixels,
            ..
        } = value;
        Self {
            color,
            pixels,
            font,
        }
    }
}
