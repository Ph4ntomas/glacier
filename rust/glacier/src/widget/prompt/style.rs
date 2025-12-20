//! [`Prompt`] widget styling.
//!
//! [`Prompt`]: crate::widget::prompt::Prompt

use snowcap_api::widget::{
    Border, Color, Padding,
    font::Font,
    text_input::{self, Icon},
};

/// State based appearance of a [`Prompt`].
///
/// [`Prompt`]: super::Prompt
#[derive(Clone, Default)]
pub struct PromptStyle {
    /// [`Color`] used to render the text.
    pub fg_color: Option<Color>,
    /// [`Background`] used for the [`Prompt`].
    ///
    /// [`Prompt`]: super::Prompt
    pub bg_color: Option<Color>,
    /// [`Border`] surrounding the [`Prompt`].
    ///
    /// [`Prompt`]: super::Prompt
    pub border: Option<Border>,
    /// [`Color`] used to render the [`Icon`]
    pub icon_color: Option<Color>,
    /// [`Color`] used to display the placeholder.
    pub placeholder_color: Option<Color>,
    /// [`Color`] used to display the selection.
    pub selection_color: Option<Color>,
}

/// Appearance of a [`Prompt`].
///
/// [`Prompt`]: super::Prompt
#[derive(Clone, Default)]
pub struct Style {
    /// [`Font`] to use to render state.
    pub font: Option<Font>,
    /// [`Icon`] to display on the left or right side of the [`Prompt`]
    ///
    /// [`Prompt`]: super::Prompt
    pub icon: Option<Icon>,
    /// [`Padding`] used inside the prompt.
    pub padding: Option<Padding>,
    /// Default [`PromptStyle`] options.
    pub default: PromptStyle,
    /// [`PromptStyle`] overrides for active [`Prompt`]
    ///
    /// [`Prompt`]: super::Prompt
    pub active: Option<PromptStyle>,
    /// [`PromptStyle`] overrides for focused [`Prompt`]
    ///
    /// [`Prompt`]: super::Prompt
    pub focused: Option<PromptStyle>,
}

impl Style {
    /// Create a new [`Style`] with default values.
    pub fn new() -> Self {
        Self::default()
    }

    /// Sets the [`Font`] used to render text.
    pub fn font(self, font: Font) -> Self {
        Self {
            font: Some(font),
            ..self
        }
    }

    /// Sets the [`Icon`] to display on the side.
    pub fn icon(self, icon: Icon) -> Self {
        Self {
            icon: Some(icon),
            ..self
        }
    }

    /// Sets the [`Padding`].
    pub fn padding(self, padding: Padding) -> Self {
        Self {
            padding: Some(padding),
            ..self
        }
    }

    /// Sets the default [`PromptStyle`] options.
    pub fn style(self, style: PromptStyle) -> Self {
        Self {
            default: style,
            ..self
        }
    }

    /// Sets overrides to use when the [`Prompt`] is active.
    ///
    /// [`Prompt`]: super::Prompt
    pub fn active(self, active: PromptStyle) -> Self {
        Self {
            active: Some(active),
            ..self
        }
    }

    /// Sets overrides to use when the [`Prompt`] is focused.
    ///
    /// [`Prompt`]: super::Prompt
    pub fn focused(self, focused: PromptStyle) -> Self {
        Self {
            focused: Some(focused),
            ..self
        }
    }

    /// Sets the text [`Color`].
    pub fn fg_color(self, fg_color: Color) -> Self {
        Self {
            default: self.default.fg_color(fg_color),
            ..self
        }
    }

    /// Sets the [`Background`] to a plain color.
    pub fn bg_color(self, bg_color: Color) -> Self {
        Self {
            default: self.default.bg_color(bg_color),
            ..self
        }
    }

    /// Sets the [`Border`].
    pub fn border(self, border: Border) -> Self {
        Self {
            default: self.default.border(border),
            ..self
        }
    }

    /// Sets the [`Color`] used to render the [`Icon`].
    pub fn icon_color(self, icon_color: Color) -> Self {
        Self {
            default: self.default.icon_color(icon_color),
            ..self
        }
    }

    /// Sets the [`Color`] used to render the placeholder text.
    pub fn placeholder_color(self, placeholder_color: Color) -> Self {
        Self {
            default: self.default.placeholder_color(placeholder_color),
            ..self
        }
    }

    /// Sets the [`Color`] used to render selected text.
    pub fn selection_color(self, selection_color: Color) -> Self {
        Self {
            default: self.default.selection_color(selection_color),
            ..self
        }
    }

    /// Get the [`PromptStyle`] for an active [`Prompt`].
    ///
    /// This `PromptStyle` is build from [`Style::default`] with overrides from [`Style::active`]
    ///
    /// [`Prompt`]: super::Prompt
    pub fn get_active(&self) -> PromptStyle {
        if let Some(style) = &self.active {
            style.apply_default(&self.default)
        } else {
            self.default.clone()
        }
    }

    /// Get the [`PromptStyle`] for a focused [`Prompt`].
    ///
    /// This `PromptStyle` is build from [`Style::default`] with overrides from [`Style::focused`]
    ///
    /// [`Prompt`]: super::Prompt
    pub fn get_focused(&self) -> PromptStyle {
        if let Some(style) = self.focused.as_ref().or(self.active.as_ref()) {
            style.apply_default(&self.default)
        } else {
            self.default.clone()
        }
    }
}

impl PromptStyle {
    /// Create a new [`PromptStyle`].
    pub fn new() -> Self {
        Self::default()
    }

    /// Sets the text [`Color`].
    pub fn fg_color(self, fg_color: Color) -> Self {
        Self {
            fg_color: Some(fg_color),
            ..self
        }
    }

    /// Sets the [`Background`] to a plain color.
    pub fn bg_color(self, bg_color: Color) -> Self {
        Self {
            bg_color: Some(bg_color),
            ..self
        }
    }

    /// Sets the [`Border`].
    pub fn border(self, border: Border) -> Self {
        Self {
            border: Some(border),
            ..self
        }
    }

    /// Sets the [`Color`] used to render the [`Icon`].
    pub fn icon_color(self, icon_color: Color) -> Self {
        Self {
            icon_color: Some(icon_color),
            ..self
        }
    }

    /// Sets the [`Color`] used to render the placeholder text.
    pub fn placeholder_color(self, placeholder_color: Color) -> Self {
        Self {
            placeholder_color: Some(placeholder_color),
            ..self
        }
    }

    /// Sets the [`Color`] used to render selected text.
    pub fn selection_color(self, selection_color: Color) -> Self {
        Self {
            selection_color: Some(selection_color),
            ..self
        }
    }

    /// Apply default value for unset fields.
    pub fn apply_default(&self, default: &Self) -> Self {
        let PromptStyle {
            fg_color,
            bg_color,
            border,
            icon_color,
            placeholder_color,
            selection_color,
        } = self.clone();

        Self {
            fg_color: fg_color.or(default.fg_color),
            bg_color: bg_color.or(default.bg_color),
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
            bg_color,
            border,
            icon_color,
            placeholder_color,
            selection_color,
        } = value;

        Self {
            background_color: bg_color,
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
