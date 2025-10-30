use regex::Regex;
use snowcap_api::widget::Color;

fn parse_hex(hex: &str) -> (f32, f32, f32) {
    let re = Regex::new(r"^#([[:xdigit:]]{2})([[:xdigit:]]{2})([[:xdigit:]]{2})$")
        .expect("Failed to compile regex");

    re.captures(hex.as_ref())
        .map(|cs| (cs[1].to_string(), cs[2].to_string(), cs[3].to_string()))
        .or_else(|| {
            let re = Regex::new(r"^#([[:xdigit:]])([[:xdigit:]])([[:xdigit:]])$")
                .expect("Failed to compile regex");
            re.captures(hex.as_ref())
                .map(|cs| (cs[1].repeat(2), cs[2].repeat(2), cs[3].repeat(2)))
        })
        .map(|(r, g, b)| {
            (
                i32::from_str_radix(&r, 16).unwrap(),
                i32::from_str_radix(&g, 16).unwrap(),
                i32::from_str_radix(&b, 16).unwrap(),
            )
        })
        .map(|(r, g, b)| ((r as f32) / 255.0, (g as f32) / 255.0, (b as f32) / 255.0))
        .unwrap_or_else(|| panic!("Invalid hex code. Expected '#RRGGBB' or '#RGB', got '{hex}'"))
}

pub fn from_hex(hex: impl AsRef<str>) -> Color {
    let (r, g, b) = parse_hex(hex.as_ref());

    Color::rgb(r, g, b)
}

pub fn from_hex_alpha(hex: impl AsRef<str>, alpha: f32) -> Color {
    let (r, g, b) = parse_hex(hex.as_ref());

    Color::rgba(r, g, b, alpha)
}
