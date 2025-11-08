//! Pre-made separators.

/// Arrows shapes
pub mod arrow {
    use crate::misc::image::AlphaMask;

    const B: u8 = 255;
    const L: u8 = 0;

    /// Right pointing arrow
    pub fn right() -> AlphaMask {
        #[rustfmt::skip]
        let mask = [
            B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,
            B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,
            B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,
            B,B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,
            B,B,B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,
            B,B,B,B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,
            B,B,B,B,B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,
            B,B,B,B,B,B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,
            B,B,B,B,B,B,B,B,B,B,L,L,L,L,L,L,L,L,L,L,
            B,B,B,B,B,B,B,B,B,B,B,L,L,L,L,L,L,L,L,L,
            B,B,B,B,B,B,B,B,B,B,B,B,L,L,L,L,L,L,L,L,
            B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,L,L,L,L,L,
            B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,L,L,L,L,
            B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,L,L,L,
            B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,L,L,
            B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,L,
            B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,
            B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,
            B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,L,
            B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,L,L,
            B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,L,L,L,
            B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,L,L,L,L,
            B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,L,L,L,L,L,
            B,B,B,B,B,B,B,B,B,B,B,B,L,L,L,L,L,L,L,L,
            B,B,B,B,B,B,B,B,B,B,B,L,L,L,L,L,L,L,L,L,
            B,B,B,B,B,B,B,B,B,B,L,L,L,L,L,L,L,L,L,L,
            B,B,B,B,B,B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,
            B,B,B,B,B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,
            B,B,B,B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,
            B,B,B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,
            B,B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,
            B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,
            B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,
            B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,
        ];

        AlphaMask::new(20, 34, mask)
    }

    /// Transparent right pointing arrow.
    pub fn right_inv() -> AlphaMask {
        #[rustfmt::skip]
        let mask = [
            L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,
            L,L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,
            L,L,L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,
            L,L,L,L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,
            L,L,L,L,L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,
            L,L,L,L,L,L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,
            L,L,L,L,L,L,L,L,B,B,B,B,B,B,B,B,B,B,B,B,
            L,L,L,L,L,L,L,L,L,B,B,B,B,B,B,B,B,B,B,B,
            L,L,L,L,L,L,L,L,L,L,B,B,B,B,B,B,B,B,B,B,
            L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,B,B,B,B,B,
            L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,B,B,B,B,
            L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,B,B,B,
            L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,B,B,
            L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,B,
            L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,
            L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,
            L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,
            L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,
            L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,
            L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,
            L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,B,
            L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,B,B,
            L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,B,B,B,
            L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,B,B,B,B,
            L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,B,B,B,B,B,
            L,L,L,L,L,L,L,L,L,L,B,B,B,B,B,B,B,B,B,B,
            L,L,L,L,L,L,L,L,L,B,B,B,B,B,B,B,B,B,B,B,
            L,L,L,L,L,L,L,L,B,B,B,B,B,B,B,B,B,B,B,B,
            L,L,L,L,L,L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,
            L,L,L,L,L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,
            L,L,L,L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,
            L,L,L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,
            L,L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,
            L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,
        ];

        AlphaMask::new(20, 34, mask)
    }

    /// Left pointing arrow.
    pub fn left() -> AlphaMask {
        #[rustfmt::skip]
        let mask = [
            L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,
            L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,
            L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,
            L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,B,
            L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,B,B,
            L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,B,B,B,
            L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,B,B,B,B,
            L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,B,B,B,B,B,
            L,L,L,L,L,L,L,L,L,L,B,B,B,B,B,B,B,B,B,B,
            L,L,L,L,L,L,L,L,L,B,B,B,B,B,B,B,B,B,B,B,
            L,L,L,L,L,L,L,L,B,B,B,B,B,B,B,B,B,B,B,B,
            L,L,L,L,L,L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,
            L,L,L,L,L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,
            L,L,L,L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,
            L,L,L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,
            L,L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,
            L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,
            L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,
            L,L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,
            L,L,L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,
            L,L,L,L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,
            L,L,L,L,L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,B,
            L,L,L,L,L,L,L,B,B,B,B,B,B,B,B,B,B,B,B,B,
            L,L,L,L,L,L,L,L,B,B,B,B,B,B,B,B,B,B,B,B,
            L,L,L,L,L,L,L,L,L,B,B,B,B,B,B,B,B,B,B,B,
            L,L,L,L,L,L,L,L,L,L,B,B,B,B,B,B,B,B,B,B,
            L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,B,B,B,B,B,
            L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,B,B,B,B,
            L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,B,B,B,
            L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,B,B,
            L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,B,
            L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,B,
            L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,B,
            L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,B,B,
        ];

        AlphaMask::new(20, 34, mask)
    }

    /// Left pointing transparent arrow.
    pub fn left_inv() -> AlphaMask {
        #[rustfmt::skip]
        let mask = [
            B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,
            B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,L,
            B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,L,L,
            B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,L,L,L,
            B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,L,L,L,L,
            B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,L,L,L,L,L,
            B,B,B,B,B,B,B,B,B,B,B,B,L,L,L,L,L,L,L,L,
            B,B,B,B,B,B,B,B,B,B,B,L,L,L,L,L,L,L,L,L,
            B,B,B,B,B,B,B,B,B,B,L,L,L,L,L,L,L,L,L,L,
            B,B,B,B,B,B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,
            B,B,B,B,B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,
            B,B,B,B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,
            B,B,B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,
            B,B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,
            B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,
            B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,
            B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,
            B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,
            B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,
            B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,
            B,B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,L,
            B,B,B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,L,
            B,B,B,B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,L,
            B,B,B,B,B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,L,
            B,B,B,B,B,B,B,B,B,L,L,L,L,L,L,L,L,L,L,L,
            B,B,B,B,B,B,B,B,B,B,L,L,L,L,L,L,L,L,L,L,
            B,B,B,B,B,B,B,B,B,B,B,L,L,L,L,L,L,L,L,L,
            B,B,B,B,B,B,B,B,B,B,B,B,L,L,L,L,L,L,L,L,
            B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,L,L,L,L,L,
            B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,L,L,L,L,
            B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,L,L,L,
            B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,L,L,
            B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,L,
            B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,B,L,L,
        ];

        AlphaMask::new(20, 34, mask)
    }
}
