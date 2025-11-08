//! [`TextBox`] widget styling.
//!
//! [`TextBox`]: super::TextBox

use std::collections::HashMap;

use snowcap_api::widget::{Border, Color, Padding, font::Font};

/// Per-content appearance of a [`TextBox`].
///
/// This type is passed to [`TextBox`] view function.
///
/// [`TextBox`]: super::TextBox
#[derive(Default, Clone)]
pub struct ContentStyle {
    /// Text [`Color`].
    pub fg_color: Option<Color>,
    /// Text background [`Color`].
    pub bg_color: Option<Color>,
    /// [`Border`] for the text container.
    pub border: Option<Border>,
    /// Text size, in pixels.
    pub pixels: Option<f32>,
    /// [`Font`] used to render text.
    pub font: Option<Font>,
    /// [`Padding`] for the text container.
    pub padding: Option<Padding>,
}

/// Appearance of a [`TextBox`].
///
/// [`TextBox`]: super::TextBox
#[derive(Default, Clone)]
pub struct Style {
    default: ContentStyle,
    lookup: HashMap<String, ContentStyle>,
}

/// Internal [`TextBox`] style holder.
///
/// [`TextBox`]: super::TextBox
pub(crate) enum StyleInner {
    Lookup(Style),
    Callback(Box<dyn Fn(&str) -> ContentStyle + Send + Sync>),
}

impl Style {
    /// Create a new [`Style`] using default values.
    pub fn new() -> Self {
        Self::default()
    }

    /// Sets the default [`ContentStyle`].
    pub fn with_default(self, default: ContentStyle) -> Self {
        Self { default, ..self }
    }

    /// Add a single override entry.
    pub fn add_override(self, key: impl Into<String>, style: ContentStyle) -> Self {
        let mut lookup = self.lookup;
        lookup.insert(key.into(), style);

        Self { lookup, ..self }
    }

    /// Sets per-content overrides.
    pub fn overrides<I, S>(self, overrides: I) -> Self
    where
        I: IntoIterator<Item = (S, ContentStyle)>,
        S: Into<String>,
    {
        let lookup = self
            .lookup
            .into_iter()
            .chain(overrides.into_iter().map(|(k, v)| (k.into(), v)))
            .collect();

        Self { lookup, ..self }
    }

    /// Sets default background [`Color`]
    pub fn bg_color(self, bg_color: Color) -> Self {
        Self {
            default: self.default.bg_color(bg_color),
            ..self
        }
    }

    /// Sets default text [`Color`]
    pub fn fg_color(self, fg_color: Color) -> Self {
        Self {
            default: self.default.fg_color(fg_color),
            ..self
        }
    }

    /// Sets the default [`Border`].
    pub fn border(self, border: Border) -> Self {
        Self {
            default: self.default.border(border),
            ..self
        }
    }

    /// Sets the default text size, in pixel.
    pub fn pixels(self, pixels: f32) -> Self {
        Self {
            default: self.default.pixels(pixels),
            ..self
        }
    }

    /// Sets the default [`Font`] to render text.
    pub fn font(self, font: Font) -> Self {
        Self {
            default: self.default.font(font),
            ..self
        }
    }

    /// Sets the default [`Padding`].
    pub fn padding(self, padding: Padding) -> Self {
        Self {
            default: self.default.padding(padding),
            ..self
        }
    }

    /// Get a [`ContentStyle`] for this content.
    pub fn get(&self, key: &str) -> ContentStyle {
        let Self { default, lookup } = self;

        if let Some(style) = lookup.get(key) {
            style.apply_default(default)
        } else {
            default.clone()
        }
    }
}

impl ContentStyle {
    /// Create a new [`ContentStyle`] with default values.
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

    /// Sets the text [`Color`].
    pub fn fg_color(self, fg_color: Color) -> Self {
        Self {
            fg_color: Some(fg_color),
            ..self
        }
    }

    /// Sets the [`Border`] style.
    pub fn border(self, border: Border) -> Self {
        Self {
            border: Some(border),
            ..self
        }
    }

    /// Sets the text size, in pixels.
    pub fn pixels(self, pixels: f32) -> Self {
        Self {
            pixels: Some(pixels),
            ..self
        }
    }

    /// Sets the [`Font`] to render text.
    pub fn font(self, font: Font) -> Self {
        Self {
            font: Some(font),
            ..self
        }
    }

    /// Sets the [`Padding`].
    pub fn padding(self, padding: Padding) -> Self {
        Self {
            padding: Some(padding),
            ..self
        }
    }

    /// Create a new [`ContentStyle`] by filling emtpy fields with the ones from `default`.
    pub fn apply_default(&self, default: &ContentStyle) -> Self {
        let Self {
            fg_color,
            bg_color,
            border,
            pixels,
            font,
            padding,
        } = self.clone();

        Self {
            fg_color: fg_color.or(default.fg_color),
            bg_color: bg_color.or(default.bg_color),
            border: border.or(default.border),
            pixels: pixels.or(default.pixels),
            font: font.or(default.font.clone()),
            padding: padding.or(default.padding),
        }
    }
}

impl StyleInner {
    /// Get a [`ContentStyle`] for a given `content`.
    pub fn get(&self, content: &str) -> ContentStyle {
        match self {
            Self::Lookup(lookup) => lookup.get(content),
            Self::Callback(cb) => cb(content),
        }
    }
}

impl Default for StyleInner {
    fn default() -> Self {
        Self::Lookup(Style::default())
    }
}

impl From<Style> for StyleInner {
    fn from(value: Style) -> Self {
        Self::Lookup(value)
    }
}

impl From<ContentStyle> for snowcap_api::widget::text::Style {
    fn from(value: ContentStyle) -> Self {
        Self {
            color: value.fg_color,
            pixels: value.pixels,
            font: value.font,
        }
    }
}

impl From<ContentStyle> for snowcap_api::widget::container::Style {
    fn from(value: ContentStyle) -> Self {
        Self {
            text_color: value.fg_color,
            background_color: value.bg_color,
            border: value.border,
        }
    }
}
