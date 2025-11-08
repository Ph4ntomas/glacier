pub mod bar;
pub mod keygrabber;
pub mod modal;
pub mod signal;
pub mod util;
pub mod widget;

/// Miscellaneous modules
pub mod misc {
    pub mod color;
    pub mod image;
    pub mod separator;
}

#[doc(inline)]
pub use keygrabber::KeyGrabber;

#[doc(inline)]
pub use misc::color;

#[doc(inline)]
pub use modal::modal;

#[doc(inline)]
pub use bar::Bar;
