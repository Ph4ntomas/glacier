#[derive(Debug, Clone)]
pub enum Focusable {
    Focus(String),
    Unfocus,
}

#[derive(Debug, Clone)]
pub enum Operation {
    Focusable(Focusable),
}

impl From<Focusable> for Operation {
    fn from(value: Focusable) -> Self {
        Self::Focusable(value)
    }
}
