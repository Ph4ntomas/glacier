use std::collections::HashMap;

use snowcap_api::widget::{Border, Color, Padding, font::Font};

#[derive(Default, Clone)]
pub struct ContentStyle {
    pub fg_color: Option<Color>,
    pub bg_color: Option<Color>,
    pub border: Option<Border>,
    pub pixels: Option<f32>,
    pub font: Option<Font>,
    pub padding: Option<Padding>,
}

#[derive(Default, Clone)]
pub struct StyleLookup {
    default: ContentStyle,
    lookup: HashMap<String, ContentStyle>,
}

pub enum Style {
    Lookup(StyleLookup),
    Callback(Box<dyn Fn(&str) -> ContentStyle + Send + Sync + 'static>),
}

impl StyleLookup {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn with_default(self, default: ContentStyle) -> Self {
        Self { default, ..self }
    }

    pub fn add_override(self, key: impl Into<String>, style: ContentStyle) -> Self {
        let mut lookup = self.lookup;
        lookup.insert(key.into(), style);

        Self { lookup, ..self }
    }

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

    pub fn border(self, border: Border) -> Self {
        Self {
            default: self.default.border(border),
            ..self
        }
    }

    pub fn pixels(self, pixels: f32) -> Self {
        Self {
            default: self.default.pixels(pixels),
            ..self
        }
    }

    pub fn font(self, font: Font) -> Self {
        Self {
            default: self.default.font(font),
            ..self
        }
    }

    pub fn padding(self, padding: Padding) -> Self {
        Self {
            default: self.default.padding(padding),
            ..self
        }
    }

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

    pub fn border(self, border: Border) -> Self {
        Self {
            border: Some(border),
            ..self
        }
    }

    pub fn pixels(self, pixels: f32) -> Self {
        Self {
            pixels: Some(pixels),
            ..self
        }
    }

    pub fn font(self, font: Font) -> Self {
        Self {
            font: Some(font),
            ..self
        }
    }

    pub fn padding(self, padding: Padding) -> Self {
        Self {
            padding: Some(padding),
            ..self
        }
    }

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

impl Style {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn callback<F>(callback: F) -> Self
    where
        F: Fn(&str) -> ContentStyle + Send + Sync + 'static,
    {
        Self::Callback(Box::new(callback))
    }

    pub fn get(&self, content: &str) -> ContentStyle {
        match self {
            Self::Lookup(lookup) => lookup.get(content),
            Self::Callback(cb) => cb(content),
        }
    }
}

impl Default for Style {
    fn default() -> Self {
        Self::Lookup(StyleLookup::default())
    }
}

impl From<StyleLookup> for Style {
    fn from(value: StyleLookup) -> Self {
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
