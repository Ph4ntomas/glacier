//! Simple clock widget
//!
//! [`SimpleClock`]s are simple timer based widgets which can display date and time.
//!
//! The [`format`] function accept a string using `strftime` format.

use std::{fmt::Display, time::Duration};

use chrono::TimeZone;
use snowcap_api::{
    surface::SurfaceEvent,
    widget::{self, Program, WidgetDef, base::WidgetBase, container, text},
};

use crate::util::timer::Timer;

pub mod style;
#[doc(inline)]
pub use style::Style;

/// Default [`SimpleClock`] appearance.
pub fn default_style() -> Style {
    Style::new()
}

/// [`SimpleClock`] using the local [`TimeZone`].
pub type LocalSimpleClock<Msg> = SimpleClock<Msg, chrono::Local>;
/// [`SimpleClock`] using the UTC [`TimeZone`].
pub type UtcSimpleClock<Msg> = SimpleClock<Msg, chrono::Utc>;

type ViewCallback<Msg> = Box<dyn Fn(String, Style) -> Option<WidgetDef<Msg>> + Send>;

/// [`SimpleClock`] widget.
pub struct SimpleClock<Msg, Tz> {
    base: WidgetBase,
    format: String,
    style: Style,
    view_callback: Option<ViewCallback<Msg>>,
    tz: Tz,
    refresh_timer: Timer,
}

impl<Msg, Tz> SimpleClock<Msg, Tz>
where
    Tz: TimeZone,
    Tz::Offset: Display,
{
    const DEFAULT_REFRESH: Duration = Duration::from_secs(30);
    const DEFAULT_FORMAT: &'static str = "%a. %d %b %H:%M";
    const PROGRAM_NAME: &'static str = "SimpleClock";

    /// Build a [`Clock`] with a specific [`TimeZone`]
    pub fn from_timezone(tz: Tz) -> Self {
        let base = WidgetBase::new(Self::PROGRAM_NAME);
        let mut timer = Timer::new_with_signaler(Self::DEFAULT_REFRESH, base.signaler());

        timer.on_timeout(|data| data.signaler().emit(widget::signal::RedrawNeeded));

        Self {
            base,
            format: Self::DEFAULT_FORMAT.into(),
            style: default_style(),
            view_callback: None,
            tz,
            refresh_timer: timer.clone(),
        }
    }

    /// Sets the [`SimpleClock`] refresh rate.
    pub fn refresh(self, refresh: Duration) -> Self {
        let mut refresh_timer = self.refresh_timer;
        refresh_timer.interval(refresh);

        Self {
            refresh_timer,
            ..self
        }
    }

    /// Sets the [`SimpleClock`] format string.
    pub fn format(self, format: impl Into<String>) -> Self {
        Self {
            format: format.into(),
            ..self
        }
    }

    /// Sets the [`SimpleClock`] style.
    pub fn style(self, style: Style) -> Self {
        Self { style, ..self }
    }

    /// Sets the [`SimpleClock`] view function.
    pub fn view_callback<F>(self, callback: F) -> Self
    where
        F: Fn(String, Style) -> Option<WidgetDef<Msg>> + Send + 'static,
    {
        Self {
            view_callback: Some(Box::new(callback)),
            ..self
        }
    }

    fn get_content(&self) -> String {
        let format = self.format.as_ref();

        chrono::Utc::now()
            .with_timezone(&self.tz)
            .format(format)
            .to_string()
    }
}

impl<Msg, Tz> SimpleClock<Msg, Tz> {
    /// [`SimpleClock`] default view function.
    pub fn default_view(content: String, mut style: Style) -> Option<WidgetDef<Msg>> {
        let content = text::Text::new(content)
            .height(widget::Length::Fill)
            .width(widget::Length::Shrink)
            .vertical_alignment(widget::Alignment::Center)
            .style(style.clone().into());

        let padding = style.padding.take();

        let mut container = container::Container::new(content)
            .height(widget::Length::Fill)
            .width(widget::Length::Shrink)
            .vertical_alignment(widget::Alignment::Center)
            .style(style.into());

        container.padding = padding;

        Some(container.into())
    }
}

impl<Msg> SimpleClock<Msg, chrono::Local> {
    /// create a new [`SimpleClock`] using the local [`TimeZone`].
    pub fn new() -> Self {
        SimpleClock::from_timezone(chrono::Local)
    }
}

impl<Msg> SimpleClock<Msg, chrono::Utc> {
    /// create a new [`SimpleClock`] using the UTC [`TimeZone`].
    pub fn new() -> Self {
        SimpleClock::from_timezone(chrono::Utc)
    }
}

impl<Msg, Tz> Program for SimpleClock<Msg, Tz>
where
    Tz: TimeZone,
    Tz::Offset: Display,
{
    type Message = Msg;

    fn view(&self) -> Option<snowcap_api::widget::WidgetDef<Self::Message>> {
        let content = self.get_content();

        let style = self.style.clone();
        if let Some(callback) = self.view_callback.as_ref() {
            callback(content, style)
        } else {
            SimpleClock::<Msg, Tz>::default_view(content, style)
        }
    }

    fn event(&mut self, event: SurfaceEvent<Self::Message>) {
        if let SurfaceEvent::Created { .. } = event {
            self.refresh_timer.start(false);
        }
    }

    fn update(&mut self, _msg: Self::Message) {}

    fn signaler(&self) -> Option<snowcap_api::signal::Signaler> {
        Some(self.base.signaler())
    }
}

impl<Msg> Default for SimpleClock<Msg, chrono::Local> {
    fn default() -> Self {
        Self::new()
    }
}

impl<Msg> Default for SimpleClock<Msg, chrono::Utc> {
    fn default() -> Self {
        Self::new()
    }
}
