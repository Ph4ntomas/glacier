use snowcap_api::widget::{
    Color,
    image::{self},
};

#[derive(Clone)]
pub struct AlphaMask {
    pub width: usize,
    pub height: usize,
    pub color: Option<Color>,
    pub mask: Vec<u8>,
}

impl AlphaMask {
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

    pub fn color(self, color: Color) -> Self {
        Self {
            color: Some(color),
            ..self
        }
    }

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

    pub fn to_image(&self, color: Option<Color>) -> image::Image {
        image::Image::new(self.to_image_handle(color))
    }
}
