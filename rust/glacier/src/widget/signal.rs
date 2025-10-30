use crate::signal::Signal;

#[derive(Clone, Copy, Debug, Signal)]
pub struct RedrawNeeded;
