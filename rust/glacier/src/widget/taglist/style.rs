use std::sync::Arc;

use snowcap_api::widget::{Border, Color, Padding, container, font::Font, text};

#[derive(Default, Clone)]
pub struct TagStyle {
    pub bg_color: Option<Color>,
    pub fg_color: Option<Color>,
    pub font: Option<Font>,
    pub pixels: Option<f32>,
    pub border: Option<Border>,
    pub padding: Option<Padding>,
}

#[derive(Default, Clone)]
pub struct Style {
    pub default: TagStyle,
    pub active: Option<TagStyle>,
    pub inactive: Option<TagStyle>,
    pub spacing: Option<f32>,
    pub hover_transform: Option<Arc<dyn Fn(TagStyle) -> TagStyle + Send + Sync>>,
}

impl TagStyle {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn bg_color(self, bg_color: Color) -> Self {
        Self {
            bg_color: Some(bg_color),
            ..self
        }
    }

    pub fn fg_color(self, fg_color: Color) -> Self {
        Self {
            fg_color: Some(fg_color),
            ..self
        }
    }

    pub fn font(self, font: Font) -> Self {
        Self {
            font: Some(font),
            ..self
        }
    }

    pub fn border(self, border: Border) -> Self {
        Self {
            border: Some(border),
            ..self
        }
    }

    pub fn padding(self, padding: Padding) -> Self {
        Self {
            padding: Some(padding),
            ..self
        }
    }

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

impl Style {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn bg_color(self, bg_color: Color) -> Self {
        Self {
            default: self.default.bg_color(bg_color),
            ..self
        }
    }

    pub fn fg_color(self, fg_color: Color) -> Self {
        Self {
            default: self.default.fg_color(fg_color),
            ..self
        }
    }

    pub fn font(self, font: Font) -> Self {
        Self {
            default: self.default.font(font),
            ..self
        }
    }

    pub fn border(self, border: Border) -> Self {
        Self {
            default: self.default.border(border),
            ..self
        }
    }

    pub fn padding(self, padding: Padding) -> Self {
        Self {
            default: self.default.padding(padding),
            ..self
        }
    }

    pub fn spacing(self, spacing: f32) -> Self {
        Self {
            spacing: Some(spacing),
            ..self
        }
    }

    pub fn active(self, active: TagStyle) -> Self {
        Self {
            active: Some(active),
            ..self
        }
    }

    pub fn inactive(self, inactive: TagStyle) -> Self {
        Self {
            inactive: Some(inactive),
            ..self
        }
    }

    pub fn hover_transform<F>(self, callback: F) -> Self
    where
        F: Fn(TagStyle) -> TagStyle + Send + Sync + 'static,
    {
        Self {
            hover_transform: Some(Arc::new(callback)),
            ..self
        }
    }

    pub fn get(&self, active: bool) -> TagStyle {
        let style = if active { &self.active } else { &self.inactive };

        if let Some(style) = style {
            style.apply_default(&self.default)
        } else {
            self.default.clone()
        }
    }
}

impl From<TagStyle> for container::Style {
    fn from(value: TagStyle) -> Self {
        Self {
            text_color: value.fg_color,
            background_color: value.bg_color,
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
