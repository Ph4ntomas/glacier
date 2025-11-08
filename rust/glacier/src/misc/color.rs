//! Color utility functions.

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

/// Convert a color in the form "#RRGGBB" or "#RGB" to a [`Color`]
pub fn from_hex(hex: impl AsRef<str>) -> Color {
    let (r, g, b) = parse_hex(hex.as_ref());

    Color::rgb(r, g, b)
}

/// Convert a color in the form "#RRGGBB" or "#RGB" to a [`Color`], and specify the alpha
/// component.
pub fn from_hex_alpha(hex: impl AsRef<str>, alpha: f32) -> Color {
    let (r, g, b) = parse_hex(hex.as_ref());

    Color::rgba(r, g, b, alpha)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn six_digit_hex() {
        let black = from_hex("#000000");
        assert_eq!(Color::rgb(0., 0., 0.), black);

        let white = from_hex("#FFFFFF");
        assert_eq!(Color::rgb(1., 1., 1.), white);

        let white_lower = from_hex("#ffffff");
        assert_eq!(Color::rgb(1., 1., 1.), white_lower);
    }

    #[test]
    fn three_digit_hex() {
        let black = from_hex("#000");
        assert_eq!(Color::rgb(0., 0., 0.), black);

        let white = from_hex("#FFF");
        assert_eq!(Color::rgb(1., 1., 1.), white);

        let white_lower = from_hex("#fff");
        assert_eq!(Color::rgb(1., 1., 1.), white_lower);
    }

    #[test]
    fn six_digit_hex_alpha() {
        let black = from_hex_alpha("#000000", 0.5);
        assert_eq!(Color::rgba(0., 0., 0., 0.5), black);

        let white = from_hex_alpha("#FFFFFF", 0.5);
        assert_eq!(Color::rgba(1., 1., 1., 0.5), white);

        let white_lower = from_hex_alpha("#ffffff", 0.5);
        assert_eq!(Color::rgba(1., 1., 1., 0.5), white_lower);
    }

    #[test]
    fn three_digit_hex_alpha() {
        let black = from_hex_alpha("#000000", 0.5);
        assert_eq!(Color::rgba(0., 0., 0., 0.5), black);

        let white = from_hex_alpha("#FFFFFF", 0.5);
        assert_eq!(Color::rgba(1., 1., 1., 0.5), white);

        let white_lower = from_hex_alpha("#ffffff", 0.5);
        assert_eq!(Color::rgba(1., 1., 1., 0.5), white_lower);
    }

    #[test]
    #[should_panic]
    fn bad_format_no_sharp() {
        parse_hex("aabbcc");
    }

    #[test]
    #[should_panic]
    fn bad_format_too_many_chars() {
        parse_hex("#FFFFFFF");
    }

    #[test]
    #[should_panic]
    fn bad_format_not_enough_chars_1() {
        parse_hex("#AABCD");
    }

    #[test]
    #[should_panic]
    fn bad_format_not_enough_chars_2() {
        parse_hex("#AA");
    }

    #[test]
    #[should_panic]
    fn bad_format_invalid_char() {
        parse_hex("#agffff");
    }
}
