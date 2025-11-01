use std::{fmt::Display, marker::PhantomData, time::Duration};

use chrono::{Local, TimeZone, Utc};
use snowcap_api::widget::{container::Container, text::Text};

use crate::{
    signal::WithEmitter,
    util::timer::Timer,
    widget::{State, Widget, WidgetMessage, WithState, base::WidgetBase, signal},
};

pub struct Inner<Msg, Tz> {
    base: WidgetBase,
    format: String,
    content: String,
    tz: Tz,
    _refresh_timer: Timer,
    _msg: PhantomData<Msg>,
}

#[derive(Clone)]
pub struct Clock<Msg, Tz> {
    state: State<Inner<Msg, Tz>>,
}

impl<Msg, Tz> Clock<Msg, Tz>
where
    Msg: Send + Sync + 'static,
    Tz: TimeZone + Send + Sync + 'static,
    Tz::Offset: Display,
{
    const DEFAULT_REFRESH: Duration = Duration::from_secs(30);
    const DEFAULT_FORMAT: &'static str = "%a. %d %b %H:%M";

    pub fn get_content(format: impl AsRef<str>, tz: &Tz) -> String {
        let format = format.as_ref();

        Utc::now().with_timezone(tz).format(format).to_string()
    }

    pub fn new_from_part(format: impl Into<String>, refresh: Duration, tz: Tz) -> Self {
        let format = format.into();

        let content = Self::get_content(&format, &tz);
        let mut timer = Timer::new(refresh);

        let state = State::new(Inner {
            base: WidgetBase::new("Clock"),
            format,
            content,
            tz,
            _refresh_timer: timer.clone(),
            _msg: PhantomData,
        });

        let for_callback = state.downgrade();

        timer.with_callback(move |_| {
            let Some(state) = for_callback.upgrade() else {
                return true;
            };

            {
                let mut inner = state.0.lock().unwrap();
                inner.content = Self::get_content(&inner.format, &inner.tz);
            }

            state.0.lock().unwrap().emit(signal::RedrawNeeded);
            false
        });
        timer.start(false);

        Self { state }
    }

    pub fn new(format: impl Into<String>, tz: Tz) -> Self {
        Self::new_from_part(format, Self::DEFAULT_REFRESH, tz)
    }
}

impl<Msg> Default for Clock<Msg, Local>
where
    Msg: Send + Sync + 'static,
{
    fn default() -> Self {
        Self::new(Self::DEFAULT_FORMAT, Local)
    }
}

impl<Msg> Default for Clock<Msg, Utc>
where
    Msg: Send + Sync + 'static,
{
    fn default() -> Self {
        Self::new(Self::DEFAULT_FORMAT, Utc)
    }
}

impl<Msg, Tz> Widget for Inner<Msg, Tz>
where
    Msg: Clone + From<WidgetMessage>,
{
    type Message = Msg;

    fn view(&self) -> Option<snowcap_api::widget::WidgetDef<Self::Message>> {
        let widget = Container::new(Text::new(self.content.clone()));

        Some(widget.into())
    }
}

impl<Msg, Tz> WithEmitter for Inner<Msg, Tz> {
    fn with_emitter(&self) -> crate::signal::Emitter {
        self.base.with_emitter()
    }
}

impl<Msg, Tz> WithState for Clock<Msg, Tz> {
    type Type = Inner<Msg, Tz>;

    fn with_state(&self) -> State<Self::Type> {
        self.state.clone()
    }
}

pub trait Buildable {
    type Msg;
    type Tz: TimeZone;

    fn timezone() -> Self::Tz;
}

impl<Msg> Buildable for Clock<Msg, Local> {
    type Msg = Msg;
    type Tz = Local;

    fn timezone() -> Self::Tz {
        Local
    }
}

impl<Msg> Buildable for Clock<Msg, Utc> {
    type Msg = Msg;
    type Tz = Utc;

    fn timezone() -> Self::Tz {
        Utc
    }
}

#[derive(Clone)]
pub struct Builder<Msg, Tz> {
    format: String,
    refresh: Duration,
    tz: Tz,
    _msg: PhantomData<Msg>,
}

impl<Msg, Tz> Builder<Msg, Tz>
where
    Msg: Send + Sync + 'static,
    Tz: TimeZone + Clone + Send + Sync + 'static,
    Tz::Offset: Display,
{
    pub fn new(tz: Tz) -> Self {
        Self {
            format: Clock::<Msg, Tz>::DEFAULT_FORMAT.into(),
            refresh: Clock::<Msg, Tz>::DEFAULT_REFRESH,
            tz,
            _msg: PhantomData,
        }
    }

    pub fn with_timezone<Tz2>(self, tz: Tz2) -> Builder<Msg, Tz2> {
        let Self {
            format, refresh, ..
        } = self;

        Builder {
            format,
            refresh,
            tz,
            _msg: PhantomData,
        }
    }

    pub fn with_format(&mut self, format: impl Into<String>) -> &mut Self {
        self.format = format.into();
        self
    }

    pub fn with_refresh(&mut self, refresh: Duration) -> &mut Self {
        self.refresh = refresh;
        self
    }

    pub fn build(&self) -> Clock<Msg, Tz> {
        Clock::new_from_part(self.format.clone(), self.refresh, self.tz.clone())
    }
}

impl<Msg> Default for Builder<Msg, Local>
where
    Msg: Clone + Send + Sync + 'static,
{
    fn default() -> Self {
        Self::new(Local)
    }
}

impl<Msg> Default for Builder<Msg, Utc>
where
    Msg: Clone + Send + Sync + 'static,
{
    fn default() -> Self {
        Self::new(Utc)
    }
}

pub fn default_builder<Msg>() -> Builder<Msg, Utc>
where
    Msg: Clone + Send + Sync + 'static,
{
    Builder::new(Utc)
}

pub fn builder<T: Buildable>() -> Builder<T::Msg, T::Tz>
where
    T::Msg: Clone + Send + Sync + 'static,
    T::Tz: TimeZone + Clone + Send + Sync + 'static,
    <T::Tz as TimeZone>::Offset: Display,
{
    Builder::new(T::timezone())
}

pub type LocalClock<Msg> = Clock<Msg, Local>;
