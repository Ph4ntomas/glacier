//! Bar style.
use snowcap_api::widget::{Border, Color, Padding};

/// Appearance of a [`Bar`].
///
/// [`Bar`]: crate::bar::Bar
#[derive(Default, Debug, Clone)]
pub struct Style {
    /// Dimension of the bar, in pixel.
    pub pixels: f32,
    /// The [`Padding`] of the bar.
    pub padding: Option<Padding>,
    /// Background [`Color`] of the bar.
    pub bg_color: Option<Color>,
    /// [`Border`] of the bar.
    pub border: Option<Border>,
    /// Spacing between elements of the bar.
    pub spacing: Option<f32>,
    /// Override spacing between element of the first area.
    pub first_spacing: Option<f32>,
    /// Override spacing between element of the middle area.
    pub center_spacing: Option<f32>,
    /// Override spacing between element of the last area.
    pub last_spacing: Option<f32>,
}

impl Style {
    /// Create a new [`Style`] with default value.
    pub fn new() -> Self {
        Self::default()
    }

    /// Sets the bar dimensions.
    pub fn pixels(self, pixels: f32) -> Self {
        Self { pixels, ..self }
    }

    /// Sets the bar [`Padding`].
    pub fn padding(self, padding: Padding) -> Self {
        Self {
            padding: Some(padding),
            ..self
        }
    }

    /// Sets the bar background [`Color`].
    pub fn bg_color(self, bg_color: Color) -> Self {
        Self {
            bg_color: Some(bg_color),
            ..self
        }
    }

    /// Sets the bar [`Border`].
    pub fn border(self, border: Border) -> Self {
        Self {
            border: Some(border),
            ..self
        }
    }

    /// Sets the spacing between elements of the bar.
    pub fn spacing(self, spacing: f32) -> Self {
        Self {
            spacing: Some(spacing),
            ..self
        }
    }

    /// Sets the spacing between widget in the first area.
    pub fn first_spacing(self, spacing: f32) -> Self {
        Self {
            first_spacing: Some(spacing),
            ..self
        }
    }

    /// Sets the spacing between widget in the center area.
    pub fn center_spacing(self, spacing: f32) -> Self {
        Self {
            center_spacing: Some(spacing),
            ..self
        }
    }

    /// Sets the spacing between widget in the last area.
    pub fn last_spacing(self, spacing: f32) -> Self {
        Self {
            last_spacing: Some(spacing),
            ..self
        }
    }

    /// Gets the spacing to apply between widgets in the first area.
    ///
    /// Returns [`Style::first_spacing`], or [`Style::spacing`] if unset.
    pub fn get_first_spacing(&self) -> Option<f32> {
        self.first_spacing.or(self.spacing)
    }

    /// Gets the spacing to apply between widgets in the center area.
    ///
    /// Returns [`Style::center_spacing`], or [`Style::spacing`] if unset.
    pub fn get_center_spacing(&self) -> Option<f32> {
        self.center_spacing.or(self.spacing)
    }

    /// Gets the spacing to apply between widgets in the last area.
    ///
    /// Returns [`Style::last_spacing`], or [`Style::spacing`] if unset.
    pub fn get_last_spacing(&self) -> Option<f32> {
        self.last_spacing.or(self.spacing)
    }
}

impl From<Style> for snowcap_api::widget::container::Style {
    fn from(value: Style) -> Self {
        let Style {
            bg_color, border, ..
        } = value;

        Self {
            text_color: None,
            background: bg_color.map(From::from),
            border,
        }
    }
}
