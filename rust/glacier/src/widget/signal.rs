use crate::signal::Signal;

#[derive(Clone, Copy, Debug, Signal)]
pub struct RedrawNeeded;

#[derive(Clone, Debug, Signal)]
pub struct RequestFocus(pub String);

#[derive(Clone, Copy, Debug, Signal)]
pub struct RequestUnfocus;
