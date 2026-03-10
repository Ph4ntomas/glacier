use snowcap_api::widget::{Border, Color, Length, Padding};

#[derive(Default, Clone, Debug)]
pub struct Style {
    pub bg_color: Option<Color>,
    pub width: Option<Length>,

    pub entry: Entry,
    pub menu_indicator: MenuIndicator,
    pub separator: Separator,

    pub padding: Option<Padding>,
    pub spacing: Option<f32>,
    pub border: Option<Border>,
}

#[derive(Default, Clone, Debug)]
pub struct Entry {
    pub default: EntryState,
    pub selected: EntryState,
    pub disabled: EntryState,

    pub height: f32,
    pub padding: Option<Padding>,
}

#[derive(Default, Clone, Debug)]
pub struct EntryState {
    pub fg_color: Option<Color>,
    pub bg_color: Option<Color>,
    pub border: Option<Border>,
}

#[derive(Default, Clone, Debug)]
pub struct MenuIndicator {
    pub color: Option<Color>,
    pub color_disabled: Option<Color>,
    pub color_selected: Option<Color>,

    pub width: Option<Length>,
    pub height: Option<Length>,
}

#[derive(Default, Clone, Debug)]
pub struct Separator {
    pub fg_color: Option<Color>,
    pub bg_color: Option<Color>,

    pub padding: Padding,
    pub thickness: f32,
}

impl EntryState {
    pub fn merge(&self, other: &EntryState) -> Self {
        let EntryState {
            fg_color,
            bg_color,
            border,
        } = other;

        Self {
            fg_color: fg_color.or(self.fg_color),
            bg_color: bg_color.or(self.bg_color),
            border: border.or(self.border),
        }
    }
}
