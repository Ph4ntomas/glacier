use snowcap_api::widget::{Border, Color, Padding};

#[derive(Default, Debug, Clone)]
pub struct Style {
    /// Dimension of the bar, in pixel.
    pub pixels: f32,
    pub padding: Option<Padding>,
    pub bg_color: Option<Color>,
    pub border: Option<Border>,
    pub spacing: Option<f32>,
    pub first_spacing: Option<f32>,
    pub center_spacing: Option<f32>,
    pub last_spacing: Option<f32>,
}

impl Style {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn pixels(self, pixels: f32) -> Self {
        Self { pixels, ..self }
    }

    pub fn padding(self, padding: Padding) -> Self {
        Self {
            padding: Some(padding),
            ..self
        }
    }

    pub fn bg_color(self, bg_color: Color) -> Self {
        Self {
            bg_color: Some(bg_color),
            ..self
        }
    }

    pub fn border(self, border: Border) -> Self {
        Self {
            border: Some(border),
            ..self
        }
    }

    pub fn spacing(self, spacing: f32) -> Self {
        Self {
            spacing: Some(spacing),
            ..self
        }
    }

    pub fn first_spacing(self, spacing: f32) -> Self {
        Self {
            first_spacing: Some(spacing),
            ..self
        }
    }

    pub fn center_spacing(self, spacing: f32) -> Self {
        Self {
            center_spacing: Some(spacing),
            ..self
        }
    }

    pub fn last_spacing(self, spacing: f32) -> Self {
        Self {
            last_spacing: Some(spacing),
            ..self
        }
    }

    pub fn get_first_spacing(&self) -> Option<f32> {
        self.first_spacing.or(self.spacing)
    }

    pub fn get_center_spacing(&self) -> Option<f32> {
        self.center_spacing.or(self.spacing)
    }

    pub fn get_last_spacing(&self) -> Option<f32> {
        self.last_spacing.or(self.spacing)
    }
}

impl From<Style> for snowcap_api::widget::container::Style {
    fn from(value: Style) -> Self {
        let Style {
            bg_color: background_color,
            border,
            ..
        } = value;

        Self {
            text_color: None,
            background_color,
            border,
        }
    }
}
