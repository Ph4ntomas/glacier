pub mod bar;
pub mod keygrabber;
pub mod logging;
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

pub trait BlockOnTokio {
    type Output;

    fn block_on_tokio(self) -> Self::Output;
}

impl<F: Future> BlockOnTokio for F {
    type Output = F::Output;

    /// Blocks on a future using the current Tokio runtime.
    fn block_on_tokio(self) -> Self::Output {
        tokio::task::block_in_place(|| {
            let handle = tokio::runtime::Handle::current();
            handle.block_on(self)
        })
    }
}
