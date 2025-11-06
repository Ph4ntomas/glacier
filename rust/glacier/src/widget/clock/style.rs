use snowcap_api::widget::{Border, Color, Padding, container, font::Font, text};

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
            background_color: bg_color,
            border,
        }
    }
}
