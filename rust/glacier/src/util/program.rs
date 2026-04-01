use snowcap_api::widget::Program;

/// An extension trait for [`Program`]s.
pub trait ProgramExt: snowcap_api::widget::Program + Send {
    /// Wrap the program in a Box.
    fn boxed<'a>(self) -> Box<dyn Program<Message = Self::Message> + Send + 'a>
    where
        Self: Sized + Send + 'a,
    {
        Box::new(self)
    }
}

impl<T: ?Sized> ProgramExt for T where T: Program + Send {}

/// Create a [`Vec`] of boxed [`Program`].
///
/// `programs!` is a shorthand to create a `Vec` of `Program` from disjointed types using the
/// array-expression syntax.
///
/// Internally, it uses [ProgramExt::boxed] to wrap every expressions passed as parameters.
#[macro_export]
macro_rules! programs {
    () => [
        std::vec::Vec::new()
    ];
    ($($child:expr),+ $(,)?) => [
        vec![
            $(glacier::util::program::ProgramExt::boxed($child)),*
        ]
    ];
}
