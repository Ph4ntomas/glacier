use std::{fmt::Display, time::Duration};

use chrono::{Local, TimeZone, Utc};
use snowcap_api::widget::{self, WidgetDef, container, text::Text};

use crate::{
    signal::{HandlerPolicy, WithEmitter},
    util::timer::Timer,
    widget::{State, WeakState, Widget, WidgetMessage, WithState, base::WidgetBase, signal},
};

pub mod style;
use style::Style;

pub type LocalClock<Msg> = Clock<Msg, Local>;
pub type UtcClock<Msg> = Clock<Msg, Local>;

type ViewCallback<Msg> = Box<dyn Fn(String, Style) -> Option<WidgetDef<Msg>> + Sync + Send>;

pub struct Inner<Msg, Tz> {
    base: WidgetBase,
    format: String,
    style: Style,
    view_callback: Option<ViewCallback<Msg>>,
    tz: Tz,
    refresh_timer: Timer,
}

#[derive(Clone)]
pub struct Clock<Msg, Tz> {
    state: State<Inner<Msg, Tz>>,
}

pub struct WeakClock<Msg, Tz>(WeakState<Inner<Msg, Tz>>);

pub fn default_style() -> Style {
    Style::new()
}

impl<Msg, Tz> Clock<Msg, Tz>
where
    Msg: Send + Sync + 'static,
    Tz: TimeZone + Send + Sync + 'static,
{
    const DEFAULT_REFRESH: Duration = Duration::from_secs(30);
    const DEFAULT_FORMAT: &'static str = "%a. %d %b %H:%M";

    pub fn from_timezone(tz: Tz) -> Self {
        let mut timer = Timer::new(Self::DEFAULT_REFRESH);

        let state = State::new(Inner {
            base: WidgetBase::new("Clock"),
            format: Self::DEFAULT_FORMAT.into(),
            style: default_style(),
            view_callback: None,
            tz,
            refresh_timer: timer.clone(),
        });

        let ret = Self { state };

        timer.with_callback({
            let weak = ret.downgrade();
            move |_| {
                let Some(clock) = weak.upgrade() else {
                    return HandlerPolicy::Discard;
                };

                clock.emit(signal::RedrawNeeded);
                HandlerPolicy::Keep
            }
        });
        timer.start(false);

        ret
    }

    pub fn refresh(self, refresh: Duration) -> Self {
        {
            let mut inner = self.state.0.lock().unwrap();
            inner.refresh_timer.interval(refresh);
            inner.refresh_timer.restart(false);
        }

        self
    }

    pub fn format(self, format: impl Into<String>) -> Self {
        self.state.0.lock().unwrap().format = format.into();
        self.emit(signal::RedrawNeeded);
        self
    }

    pub fn style(self, style: Style) -> Self {
        self.state.0.lock().unwrap().style = style;
        self
    }

    pub fn view_callback<F>(self, callback: F) -> Self
    where
        F: Fn(String, Style) -> Option<WidgetDef<Msg>> + Send + Sync + 'static,
    {
        self.state.0.lock().unwrap().view_callback = Some(Box::new(callback));
        self
    }

    pub fn downgrade(&self) -> WeakClock<Msg, Tz> {
        WeakClock(self.state.downgrade())
    }
}

impl<Msg, Tz> Clock<Msg, Tz> {
    pub fn default_view(content: String, mut style: Style) -> Option<WidgetDef<Msg>> {
        let content = Text::new(content)
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

impl<Msg> Clock<Msg, Local>
where
    Msg: Send + Sync + 'static,
{
    pub fn new() -> Self {
        Clock::from_timezone(Local)
    }
}

impl<Msg> Clock<Msg, Utc>
where
    Msg: Send + Sync + 'static,
{
    pub fn new() -> Self {
        Clock::from_timezone(Utc)
    }
}

impl<Msg, Tz> WeakClock<Msg, Tz> {
    pub fn upgrade(&self) -> Option<Clock<Msg, Tz>> {
        self.0.upgrade().map(|state| Clock { state })
    }
}

impl<Msg, Tz> Inner<Msg, Tz>
where
    Tz: TimeZone,
    Tz::Offset: Display,
{
    fn get_content(&self) -> String {
        let format = self.format.as_ref();

        Utc::now()
            .with_timezone(&self.tz)
            .format(format)
            .to_string()
    }
}

impl<Msg> Default for Clock<Msg, Local>
where
    Msg: Send + Sync + 'static,
{
    fn default() -> Self {
        Self::new()
    }
}

impl<Msg> Default for Clock<Msg, Utc>
where
    Msg: Send + Sync + 'static,
{
    fn default() -> Self {
        Self::new()
    }
}

impl<Msg, Tz> Widget for Inner<Msg, Tz>
where
    Msg: Clone + From<WidgetMessage>,
    Tz: TimeZone,
    Tz::Offset: Display,
{
    type Message = Msg;

    fn view(&self) -> Option<snowcap_api::widget::WidgetDef<Self::Message>> {
        let content = self.get_content();

        let style = self.style.clone();
        if let Some(callback) = &self.view_callback {
            callback(content, style)
        } else {
            Clock::<Msg, Tz>::default_view(content, style)
        }
    }
}

impl<Msg, Tz> WithEmitter for Inner<Msg, Tz> {
    fn with_emitter(&self) -> crate::signal::Emitter {
        self.base.with_emitter()
    }
}

impl<Msg, Tz> WithEmitter for Clock<Msg, Tz> {
    fn with_emitter(&self) -> crate::signal::Emitter {
        self.state.0.lock().unwrap().with_emitter()
    }
}

impl<Msg, Tz> WithState for Clock<Msg, Tz> {
    type Type = Inner<Msg, Tz>;

    fn with_state(&self) -> State<Self::Type> {
        self.state.clone()
    }
}
