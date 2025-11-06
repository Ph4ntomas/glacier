use snowcap_api::widget::{
    Background, Border, Color, Padding,
    font::Font,
    text_input::{self, Icon},
};

#[derive(Clone, Default)]
pub struct PromptStyle {
    pub fg_color: Option<Color>,
    pub background: Option<Background>,
    pub border: Option<Border>,
    pub icon_color: Option<Color>,
    pub placeholder_color: Option<Color>,
    pub selection_color: Option<Color>,
}

#[derive(Clone, Default)]
pub struct Style {
    pub font: Option<Font>,
    pub icon: Option<Icon>,
    pub padding: Option<Padding>,
    pub default: PromptStyle,
    pub active: Option<PromptStyle>,
    pub focused: Option<PromptStyle>,
}

impl Style {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn font(self, font: Font) -> Self {
        Self {
            font: Some(font),
            ..self
        }
    }

    pub fn icon(self, icon: Icon) -> Self {
        Self {
            icon: Some(icon),
            ..self
        }
    }

    pub fn padding(self, padding: Padding) -> Self {
        Self {
            padding: Some(padding),
            ..self
        }
    }

    pub fn style(self, style: PromptStyle) -> Self {
        Self {
            default: style,
            ..self
        }
    }

    pub fn active(self, active: PromptStyle) -> Self {
        Self {
            active: Some(active),
            ..self
        }
    }

    pub fn focused(self, focused: PromptStyle) -> Self {
        Self {
            focused: Some(focused),
            ..self
        }
    }

    pub fn fg_color(self, fg_color: Color) -> Self {
        Self {
            default: self.default.fg_color(fg_color),
            ..self
        }
    }

    pub fn bg_color(self, bg_color: Color) -> Self {
        Self {
            default: self.default.bg_color(bg_color),
            ..self
        }
    }

    pub fn background(self, background: impl Into<Background>) -> Self {
        Self {
            default: self.default.background(background),
            ..self
        }
    }

    pub fn border(self, border: Border) -> Self {
        Self {
            default: self.default.border(border),
            ..self
        }
    }

    pub fn icon_color(self, icon_color: Color) -> Self {
        Self {
            default: self.default.icon_color(icon_color),
            ..self
        }
    }

    pub fn placeholder_color(self, placeholder_color: Color) -> Self {
        Self {
            default: self.default.placeholder_color(placeholder_color),
            ..self
        }
    }

    pub fn selection_color(self, selection_color: Color) -> Self {
        Self {
            default: self.default.selection_color(selection_color),
            ..self
        }
    }

    pub fn get_active(&self) -> PromptStyle {
        if let Some(style) = &self.active {
            style.apply_default(&self.default)
        } else {
            self.default.clone()
        }
    }

    pub fn get_focused(&self) -> PromptStyle {
        if let Some(style) = self.focused.as_ref().or(self.active.as_ref()) {
            style.apply_default(&self.default)
        } else {
            self.default.clone()
        }
    }
}

impl PromptStyle {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn fg_color(self, fg_color: Color) -> Self {
        Self {
            fg_color: Some(fg_color),
            ..self
        }
    }

    pub fn bg_color(self, bg_color: Color) -> Self {
        Self {
            background: Some(bg_color.into()),
            ..self
        }
    }

    pub fn background(self, background: impl Into<Background>) -> Self {
        Self {
            background: Some(background.into()),
            ..self
        }
    }

    pub fn border(self, border: Border) -> Self {
        Self {
            border: Some(border),
            ..self
        }
    }

    pub fn icon_color(self, icon_color: Color) -> Self {
        Self {
            icon_color: Some(icon_color),
            ..self
        }
    }

    pub fn placeholder_color(self, placeholder_color: Color) -> Self {
        Self {
            placeholder_color: Some(placeholder_color),
            ..self
        }
    }

    pub fn selection_color(self, selection_color: Color) -> Self {
        Self {
            selection_color: Some(selection_color),
            ..self
        }
    }

    pub fn apply_default(&self, default: &Self) -> Self {
        let PromptStyle {
            fg_color,
            background,
            border,
            icon_color,
            placeholder_color,
            selection_color,
        } = self.clone();

        Self {
            fg_color: fg_color.or(default.fg_color),
            background: background.or_else(|| default.background.clone()),
            border: border.or(default.border),
            icon_color: icon_color.or(default.icon_color),
            placeholder_color: placeholder_color.or(default.placeholder_color),
            selection_color: selection_color.or(default.selection_color),
        }
    }
}

impl From<PromptStyle> for text_input::Style {
    fn from(value: PromptStyle) -> Self {
        let PromptStyle {
            fg_color,
            background,
            border,
            icon_color,
            placeholder_color,
            selection_color,
        } = value;

        Self {
            background,
            border,
            icon: icon_color,
            placeholder: placeholder_color,
            value: fg_color,
            selection: selection_color,
        }
    }
}

impl From<Style> for text_input::Styles {
    fn from(value: Style) -> Self {
        Self {
            active: Some(value.get_active().into()),
            focused: Some(value.get_focused().into()),
            disabled: Some(value.get_active().into()), // FIXME: Workaround rendering bug
            ..Self::default()
        }
    }
}
