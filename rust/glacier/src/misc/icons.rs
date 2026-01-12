//! Pre-made icons.

/// Menu icons
pub mod menu {
    use crate::misc::image::AlphaMask;

    const B: u8 = 255;
    const L: u8 = 0;

    /// Menu indicator.
    pub fn menu_indicator() -> AlphaMask {
        #[rustfmt::skip]
        let mask = [
            L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,
            L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,
            B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,
            B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,
            B,B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,
            L,B,B,B,B,B,L,L,L,L,L,L,L,L,L,L,
            L,L,B,B,B,B,B,L,L,L,L,L,L,L,L,L,
            L,L,L,B,B,B,B,B,L,L,L,L,L,L,L,L,
            L,L,L,L,B,B,B,B,B,L,L,L,L,L,L,L,
            L,L,L,L,L,B,B,B,B,B,L,L,L,L,L,L,
            L,L,L,L,L,L,B,B,B,B,B,L,L,L,L,L,
            L,L,L,L,L,L,L,B,B,B,B,B,L,L,L,L,
            L,L,L,L,L,L,L,L,B,B,B,B,B,L,L,L,
            L,L,L,L,L,L,L,L,L,B,B,B,B,B,L,L,
            L,L,L,L,L,L,L,L,L,L,B,B,B,B,B,L,
            L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,B,
            L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,B,
            L,L,L,L,L,L,L,L,L,L,B,B,B,B,B,L,
            L,L,L,L,L,L,L,L,L,B,B,B,B,B,L,L,
            L,L,L,L,L,L,L,L,B,B,B,B,B,L,L,L,
            L,L,L,L,L,L,L,B,B,B,B,B,L,L,L,L,
            L,L,L,L,L,L,B,B,B,B,B,L,L,L,L,L,
            L,L,L,L,L,B,B,B,B,B,L,L,L,L,L,L,
            L,L,L,L,B,B,B,B,B,L,L,L,L,L,L,L,
            L,L,L,B,B,B,B,B,L,L,L,L,L,L,L,L,
            L,L,B,B,B,B,B,L,L,L,L,L,L,L,L,L,
            L,B,B,B,B,B,L,L,L,L,L,L,L,L,L,L,
            B,B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,
            B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,
            B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,
            L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,
            L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,
        ];

        AlphaMask::new(16, 32, mask)
    }
}

/// Radio icon
pub mod radio {
    use crate::misc::image::AlphaMask;

    const B: u8 = 255;
    const L: u8 = 0;

    /// Selected radio icon.
    pub fn selected() -> AlphaMask {
        #[rustfmt::skip]
        let mask = [
            L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,
            L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,
            L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,
            L,L,L,L,L,L,L,L,L,L,B,B,B,B,B,B,B,B,B,B,B,B,L,L,L,L,L,L,L,L,L,L,
            L,L,L,L,L,L,L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,L,L,L,L,L,L,
            L,L,L,L,L,L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,L,L,L,L,L,
            L,L,L,L,L,L,B,B,B,B,B,B,L,L,L,L,L,L,L,L,B,B,B,B,B,B,L,L,L,L,L,L,
            L,L,L,L,L,B,B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,B,L,L,L,L,L,
            L,L,L,L,B,B,B,B,B,L,L,L,B,B,B,B,B,B,B,B,L,L,L,B,B,B,B,B,L,L,L,L,
            L,L,L,L,B,B,B,B,L,L,L,B,B,B,B,B,B,B,B,B,B,L,L,L,B,B,B,B,L,L,L,L,
            L,L,L,B,B,B,B,L,L,L,B,B,B,B,B,B,B,B,B,B,B,B,L,L,L,B,B,B,B,L,L,L,
            L,L,L,B,B,B,B,L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,B,B,B,B,L,L,L,
            L,L,L,B,B,B,L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,B,B,B,L,L,L,
            L,L,B,B,B,B,L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,B,B,B,B,L,L,
            L,L,B,B,B,B,L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,B,B,B,B,L,L,
            L,L,B,B,B,B,L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,B,B,B,B,L,L,
            L,L,B,B,B,B,L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,B,B,B,B,L,L,
            L,L,B,B,B,B,L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,B,B,B,B,L,L,
            L,L,B,B,B,B,L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,B,B,B,B,L,L,
            L,L,L,B,B,B,L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,B,B,B,L,L,L,
            L,L,L,B,B,B,B,L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,B,B,B,B,L,L,L,
            L,L,L,B,B,B,B,L,L,L,B,B,B,B,B,B,B,B,B,B,B,B,L,L,L,B,B,B,B,L,L,L,
            L,L,L,L,B,B,B,B,L,L,L,B,B,B,B,B,B,B,B,B,B,L,L,L,B,B,B,B,L,L,L,L,
            L,L,L,L,B,B,B,B,B,L,L,L,B,B,B,B,B,B,B,B,L,L,L,B,B,B,B,B,L,L,L,L,
            L,L,L,L,L,B,B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,B,L,L,L,L,L,
            L,L,L,L,L,L,B,B,B,B,B,B,L,L,L,L,L,L,L,L,B,B,B,B,B,B,L,L,L,L,L,L,
            L,L,L,L,L,L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,L,L,L,L,L,
            L,L,L,L,L,L,L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,L,L,L,L,L,L,
            L,L,L,L,L,L,L,L,L,L,B,B,B,B,B,B,B,B,B,B,B,B,L,L,L,L,L,L,L,L,L,L,
            L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,
            L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,
            L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,
        ];

        AlphaMask::new(32, 32, mask)
    }

    /// Unselected radio icon.
    pub fn unselected() -> AlphaMask {
        #[rustfmt::skip]
        let mask = [
            L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,
            L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,
            L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,
            L,L,L,L,L,L,L,L,L,L,B,B,B,B,B,B,B,B,B,B,B,B,L,L,L,L,L,L,L,L,L,L,
            L,L,L,L,L,L,L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,L,L,L,L,L,L,
            L,L,L,L,L,L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,L,L,L,L,L,
            L,L,L,L,L,L,B,B,B,B,B,B,L,L,L,L,L,L,L,L,B,B,B,B,B,B,L,L,L,L,L,L,
            L,L,L,L,L,B,B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,B,L,L,L,L,L,
            L,L,L,L,B,B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,B,L,L,L,L,
            L,L,L,L,B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,L,L,L,L,
            L,L,L,B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,L,L,L,
            L,L,L,B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,L,L,L,
            L,L,L,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,L,L,L,
            L,L,B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,L,L,
            L,L,B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,L,L,
            L,L,B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,L,L,
            L,L,B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,L,L,
            L,L,B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,L,L,
            L,L,B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,L,L,
            L,L,L,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,L,L,L,
            L,L,L,B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,L,L,L,
            L,L,L,B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,L,L,L,
            L,L,L,L,B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,L,L,L,L,
            L,L,L,L,B,B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,B,L,L,L,L,
            L,L,L,L,L,B,B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,B,L,L,L,L,L,
            L,L,L,L,L,L,B,B,B,B,B,B,L,L,L,L,L,L,L,L,B,B,B,B,B,B,L,L,L,L,L,L,
            L,L,L,L,L,L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,L,L,L,L,L,
            L,L,L,L,L,L,L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,L,L,L,L,L,L,
            L,L,L,L,L,L,L,L,L,L,B,B,B,B,B,B,B,B,B,B,B,B,L,L,L,L,L,L,L,L,L,L,
            L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,
            L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,
            L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,
        ];

        AlphaMask::new(32, 32, mask)
    }

    /// Automatically pick the button to represent the given state.
    pub fn select(toggle: bool) -> AlphaMask {
        if toggle { selected() } else { unselected() }
    }
}

/// Checkmarks
pub mod checkmark {
    use crate::misc::image::AlphaMask;

    const B: u8 = 255;
    const L: u8 = 0;

    /// Selected checkmark.
    pub fn selected() -> AlphaMask {
        #[rustfmt::skip]
        let mask = [
            L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,
            L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,
            L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,
            L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,
            L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,
            L,L,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,L,L,
            L,L,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,L,L,
            L,L,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,L,L,
            L,L,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,L,L,
            L,L,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,L,L,B,B,B,L,L,
            L,L,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,L,L,B,B,B,L,L,
            L,L,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,L,L,B,B,B,L,L,
            L,L,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,L,L,L,B,B,B,L,L,
            L,L,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,L,L,L,L,B,B,B,L,L,
            L,L,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,L,L,L,L,L,B,B,B,L,L,
            L,L,B,B,B,L,L,B,B,L,L,L,L,L,L,L,L,B,B,B,B,L,L,L,L,L,L,B,B,B,L,L,
            L,L,B,B,B,L,L,B,B,B,L,L,L,L,L,L,B,B,B,B,L,L,L,L,L,L,L,B,B,B,L,L,
            L,L,B,B,B,L,L,B,B,B,B,L,L,L,L,B,B,B,B,L,L,L,L,L,L,L,L,B,B,B,L,L,
            L,L,B,B,B,L,L,L,B,B,B,B,L,L,B,B,B,B,L,L,L,L,L,L,L,L,L,B,B,B,L,L,
            L,L,B,B,B,L,L,L,L,B,B,B,B,B,B,B,B,L,L,L,L,L,L,L,L,L,L,B,B,B,L,L,
            L,L,B,B,B,L,L,L,L,L,B,B,B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,B,B,B,L,L,
            L,L,B,B,B,L,L,L,L,L,L,B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,L,L,
            L,L,B,B,B,L,L,L,L,L,L,L,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,L,L,
            L,L,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,L,L,
            L,L,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,L,L,
            L,L,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,L,L,
            L,L,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,L,L,
            L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,
            L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,
            L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,
            L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,
            L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,
        ];

        AlphaMask::new(32, 32, mask)
    }

    /// Unelected checkmark.
    pub fn unselected() -> AlphaMask {
        #[rustfmt::skip]
        let mask = [
            L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,
            L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,
            L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,
            L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,
            L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,
            L,L,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,L,L,
            L,L,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,L,L,
            L,L,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,L,L,
            L,L,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,L,L,
            L,L,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,L,L,
            L,L,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,L,L,
            L,L,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,L,L,
            L,L,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,L,L,
            L,L,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,L,L,
            L,L,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,L,L,
            L,L,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,L,L,
            L,L,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,L,L,
            L,L,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,L,L,
            L,L,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,L,L,
            L,L,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,L,L,
            L,L,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,L,L,
            L,L,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,L,L,
            L,L,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,L,L,
            L,L,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,L,L,
            L,L,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,L,L,
            L,L,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,L,L,
            L,L,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,L,L,
            L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,
            L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,
            L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,
            L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,
            L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,
        ];

        AlphaMask::new(32, 32, mask)
    }

    /// Automatically pick the button to represent the given state.
    pub fn select(toggle: bool) -> AlphaMask {
        if toggle { selected() } else { unselected() }
    }
}

/// Miscellaneous icons
pub mod misc {
    use crate::misc::image::AlphaMask;

    const B: u8 = 255;
    const L: u8 = 0;

    /// Broken/no picture icon.
    pub fn broken_picture() -> AlphaMask {
        #[rustfmt::skip]
        let mask = [
            L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,
            L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,
            L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,L,L,L,L,L,L,
            L,L,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,L,B,B,L,L,L,L,L,L,L,
            L,L,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,L,L,B,B,L,L,L,L,L,L,
            L,L,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,L,L,L,B,B,L,L,L,L,L,
            L,L,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,L,L,L,L,B,B,L,L,L,L,
            L,L,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,L,L,L,L,L,B,B,L,L,L,
            L,L,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,L,L,L,L,L,L,B,B,L,L,
            L,L,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,L,L,L,L,L,L,L,B,L,L,
            L,L,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,B,B,B,B,B,L,L,
            L,L,B,L,L,L,L,L,L,L,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,L,L,
            L,L,B,L,L,L,L,L,L,B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,L,L,
            L,L,B,L,L,L,L,L,B,B,L,L,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,L,L,
            L,L,B,L,L,L,L,B,B,L,L,L,L,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,L,L,
            L,L,B,L,L,L,B,B,L,L,L,L,L,L,B,B,L,L,L,L,L,L,B,L,L,L,L,L,L,B,L,L,
            L,L,B,L,L,B,B,L,L,L,L,L,L,L,L,B,B,L,L,L,L,B,B,B,L,L,L,L,L,B,L,L,
            L,L,B,L,B,B,L,L,L,L,L,L,L,L,L,L,B,B,L,L,B,B,L,B,B,L,L,L,L,B,L,L,
            L,L,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,L,L,L,B,B,L,L,L,B,L,L,
            L,L,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,L,L,L,L,L,B,B,L,L,B,L,L,
            L,L,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,L,L,L,L,L,L,L,B,B,L,B,L,L,
            L,L,B,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,L,L,L,L,L,L,L,L,L,B,B,B,L,L,
            L,L,B,L,L,L,L,L,L,L,L,L,L,L,L,B,B,L,L,L,L,L,L,L,L,L,L,L,B,B,L,L,
            L,L,B,L,L,L,L,L,L,L,L,L,L,L,L,B,L,L,L,L,L,L,L,L,L,L,L,L,L,B,L,L,
            L,L,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,L,L,
            L,L,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,L,L,
            L,L,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,L,L,
            L,L,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,L,L,
            L,L,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,L,L,
            L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,
            L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,
            L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,
        ];

        AlphaMask::new(32, 32, mask)
    }
}
