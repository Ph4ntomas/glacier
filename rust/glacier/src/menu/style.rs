//! Menu's style.

use snowcap_api::widget::{Border, Color, Length, Padding};

/// Appearance of an [`Menu`].
///
/// [`Menu`]: crate::menu::Menu
#[derive(Default, Debug, Clone)]
pub struct Style {
    pub bg_color: Option<Color>,
    pub width: Option<Length>,
    pub height: Option<Length>,
    pub padding: Option<Padding>,
    pub spacing: Option<f32>,
    pub border: Option<Border>,
}

impl Style {
    /// Create a new [`Style`] with default values.
    pub fn new() -> Self {
        Self::default()
    }
}
