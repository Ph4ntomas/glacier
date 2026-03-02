/// Error returned by various widget handle methods.
#[derive(Clone, Debug)]
pub enum HandleError {
    /// The handle is stale and should be discarded.
    Stale,
}
