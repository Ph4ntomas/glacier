//! [`Clock`] style.
//!
//! [`Clock`]: super::Clock

use snowcap_api::widget::{Border, Color, Padding, container, font::Font, text};

/// Appearance of a [`Clock`].
///
/// [`Clock`]: super::Clock
#[derive(Clone, Default)]
pub struct Style {
    pub bg_color: Option<Color>,
    pub fg_color: Option<Color>,
    pub pixels: Option<f32>,
    pub font: Option<Font>,
    pub padding: Option<Padding>,
    pub border: Option<Border>,
}

impl Style {
    /// Create a new [`Style`] with default value.
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

    /// Sets the font size, in pixels
    pub fn pixels(self, pixels: f32) -> Self {
        Self {
            pixels: Some(pixels),
            ..self
        }
    }

    /// Sets the [`Font`] used to render text.
    pub fn font(self, font: Font) -> Self {
        Self {
            font: Some(font),
            ..self
        }
    }

    /// Sets [`Padding`] for the container surrounding the text.
    pub fn padding(self, padding: Padding) -> Self {
        Self {
            padding: Some(padding),
            ..self
        }
    }

    /// Sets the [`Border`] of the container surrounding the text.
    pub fn border(self, border: Border) -> Self {
        Self {
            border: Some(border),
            ..self
        }
    }
}

impl From<Style> for text::Style {
    fn from(value: Style) -> Self {
        let Style {
            fg_color,
            pixels,
            font,
            ..
        } = value;

        Self {
            color: fg_color,
            pixels,
            font,
        }
    }
}

impl From<Style> for container::Style {
    fn from(value: Style) -> Self {
        let Style {
            bg_color,
            fg_color,
            border,
            ..
        } = value;

        Self {
            text_color: fg_color,
            background: bg_color.map(From::from),
            border,
        }
    }
}
