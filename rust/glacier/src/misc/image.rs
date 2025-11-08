//! Image handling module.

use snowcap_api::widget::{
    Color,
    image::{self},
};

/// Utility type to create snowcap [`Image`]s from a mask of alpha value.
///
/// The mask is defined from an array of u8, where 0 represents full transparency.
/// It's possible to assign a default [`Color`] to the mask, which will be used if no [`Color`] is
/// passed to the `to_*` functions.
///
/// [`From`] implementations uses the default color to create the [`Image`] or [`image::Handle`].
///
/// When converting an [`AlphaMask`] to an image, the [`Color::alpha`] component is multiplied by
/// the one in the mask, while the color component are taken as-is.
///
/// [`Image`]: image::Image
#[derive(Clone)]
pub struct AlphaMask {
    width: usize,
    height: usize,
    color: Option<Color>,
    mask: Vec<u8>,
}

impl AlphaMask {
    /// Create a new [`AlphaMask`]
    pub fn new<I, V>(width: usize, height: usize, mask: I) -> Self
    where
        I: IntoIterator<Item = V>,
        V: Into<u8>,
    {
        let mask: Vec<_> = mask.into_iter().map(Into::into).collect();

        if mask.len() != (width * height) {
            panic!(
                "Invalid mask. Expected a length of {}, got {}",
                width * height,
                mask.len()
            );
        }

        Self {
            width,
            height,
            color: None,
            mask,
        }
    }

    /// Sets default color for this [`AlphaMask`]
    pub fn color(self, color: Color) -> Self {
        Self {
            color: Some(color),
            ..self
        }
    }

    /// Create a new [`AlphaMask`] by inverting every byte.
    pub fn invert(&self) -> Self {
        let Self {
            width,
            height,
            color,
            mask,
        } = self.clone();

        let mask = mask.iter().map(|v| 255 - v).collect();

        Self {
            width,
            height,
            color,
            mask,
        }
    }

    /// Create an [`image::Handle`] from this [`AlphaMask`].
    ///
    /// If `color` is set, use this instead of the default color.
    pub fn to_image_handle(&self, color: Option<Color>) -> image::Handle {
        let color = color.or(self.color).unwrap_or(Color::rgb(0.0, 0.0, 0.0));

        let red = (color.red * 255.) as u8;
        let green = (color.green * 255.) as u8;
        let blue = (color.blue * 255.) as u8;

        let bytes = self
            .mask
            .iter()
            .flat_map(|&m| [red, green, blue, (color.alpha * (m as f32)) as u8])
            .collect();

        image::Handle::Rgba {
            width: self.width as u32,
            height: self.height as u32,
            bytes,
        }
    }

    /// Create an [`image::Image`] from this [`AlphaMask`].
    ///
    /// If `color` is set, use this instead of the default color.
    pub fn to_image(&self, color: Option<Color>) -> image::Image {
        image::Image::new(self.to_image_handle(color))
    }
}

impl From<AlphaMask> for image::Handle {
    fn from(value: AlphaMask) -> Self {
        value.to_image_handle(None)
    }
}

impl From<&AlphaMask> for image::Handle {
    fn from(value: &AlphaMask) -> Self {
        value.to_image_handle(None)
    }
}

impl From<AlphaMask> for image::Image {
    fn from(value: AlphaMask) -> Self {
        value.to_image(None)
    }
}

impl From<&AlphaMask> for image::Image {
    fn from(value: &AlphaMask) -> Self {
        value.to_image(None)
    }
}
