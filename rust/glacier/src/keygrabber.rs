//! Glacier's input grabbing.
//!
//! This module contains building block to grab all keyboard input (except bound keys).
//!
//! # KeyGrabber
//! [`KeyGrabber`]s are object used to capture all keyboard inputs, passing them to callbacks for
//! processing. This can be used to implements complex interactions that might not be feasible
//! using key-binding and binding layers. As an example, it's used as the building block for the
//! [`Modal`] type, which implement VI-like key-bindings.
//!
//! # Start and Stop Events
//!
//! Callback for these events are called after the [`KeyGrabber`] start grabbing input, and after
//! it has stopped respectively. The [`on_start`] event is meant to notify calling code that input
//! grabbing has started, while the [`on_stop`] event can additionally be used to trigger other
//! [`KeyGrabber`], or to restore some state.
//!
//! # Key Events
//!
//! Key Events comes in three flavor: [`on_key_press`], [`on_key_release`] and the raw [`on_key_event`].
//!
//! The first two are simpler to used, since the key_event is processed ahead of time, and should
//! be preferred. By default said processing involves ignoring events if they are flagged as
//! captures, but this behavior can be changed by setting the [`KeyGrabber::ignore_capture`] flag.
//!
//! [`on_key_event`] callback are giver the raw unprocessed event, and should perform their own
//! processing.
//!
//! When a key_event is received, all matching callback are called, with `on_key_press` or
//! `on_key_release` being fired first, followed by `on_key_event`.
//!
//! # KeyGrabber Handles
//!
//! A [`Handle`] is an owning pointer to a [`KeyGrabber`] state, and function similarly, except it
//! cannot be used to change the callbacks, and is safe to pass around to other function. Being an
//! owning type, the lifetime of the [`KeyGrabber`] will be extended as log as at least one
//! [`Handle`] exists.
//!
//! [`WeakHandle`]s are simply non-owning version of [`Handle`]s.
//!
//! [`Modal`]: crate::modal::Modal
//! [`on_start`]: KeyGrabber::on_start
//! [`on_stop`]: KeyGrabber::on_stop
//! [`on_key_press`]: KeyGrabber::on_key_press
//! [`on_key_release`]: KeyGrabber::on_key_release
//! [`on_key_event`]: KeyGrabber::on_key_event

use std::sync::{Arc, Mutex, Weak};

use xkbcommon::xkb::Keysym;

use snowcap_api::{
    input::{KeyEvent, Modifiers},
    layer::{self, LayerHandle},
    widget::Program,
};

type KeyPressCallback =
    Box<dyn FnMut(&Handle, Modifiers, Keysym, Option<String>) + Send + Sync + 'static>;
type KeyReleaseCallback = Box<dyn FnMut(&Handle, Modifiers, Keysym) + Send + Sync + 'static>;
type KeyEventCallback = Box<dyn FnMut(&Handle, KeyEvent) + Send + Sync + 'static>;
type StartCallback = Arc<dyn Fn(&Handle) + Send + Sync + 'static>;
type StopCallback = Arc<dyn Fn(&Handle) + Send + Sync + 'static>;

struct KeyGrabberProgram;

#[derive(Default)]
struct KeyCallbackData {
    ignore_capture: bool,
    on_key_press: Option<KeyPressCallback>,
    on_key_release: Option<KeyReleaseCallback>,
    on_key_event: Option<KeyEventCallback>,
}

#[derive(Default)]
struct Inner {
    handle: Option<LayerHandle<()>>,
    callback_data: Arc<Mutex<KeyCallbackData>>,
    on_start: Option<StartCallback>,
    on_stop: Option<StopCallback>,
    paused: bool,
}

/// Handle on the [`KeyGrabber`] state.
pub struct Handle(Arc<Mutex<Inner>>);

/// Non-owning version of a [`Handle`]
#[derive(Clone)]
pub struct WeakHandle(Weak<Mutex<Inner>>);

/// Keyboard grabbing object.
///
/// See module level [documentation].
///
/// [documentation]: self
pub struct KeyGrabber {
    handle: Handle,
}

impl KeyGrabber {
    /// Create a new [`KeyGrabber`]
    pub fn new() -> Self {
        Self::default()
    }

    /// Start grabbing input.
    ///
    /// Return a [`Handle`] to the [`KeyGrabber`] state.
    pub fn start(&self) -> Handle {
        self.handle.start();

        self.handle.clone()
    }

    /// Stop grabbing input.
    pub fn stop(&self) {
        self.handle.stop();
    }

    /// Temporarily pause input grab.
    pub fn pause(&self) {
        self.handle.pause();
    }

    /// Restart input grab.
    pub fn unpause(&self) {
        self.handle.unpause();
    }

    /// Whether the [`KeyGrabber`] is running.
    ///
    /// Returns true if the `KeyGrabber` has been started but not yet stopped.
    pub fn running(&self) -> bool {
        self.handle.running()
    }

    /// Consume this [`KeyGrabber`] and return only a [`Handle`] to its state.
    pub fn freeze(self) -> Handle {
        Handle(self.handle.0.clone())
    }

    /// Ignore capture flag on events.
    pub fn ignore_capture(&mut self, ignore_capture: bool) -> &mut Self {
        self.handle.0.lock().unwrap().ignore_capture(ignore_capture);

        self
    }

    /// Sets callback to call when a key is pressed.
    pub fn on_key_press<F>(&mut self, on_key_press: F) -> &mut Self
    where
        F: FnMut(&Handle, Modifiers, Keysym, Option<String>) + Send + Sync + 'static,
    {
        self.handle.0.lock().unwrap().on_key_press(on_key_press);

        self
    }

    /// Sets callback to call when a key is released.
    pub fn on_key_release<F>(&mut self, on_key_release: F) -> &mut Self
    where
        F: FnMut(&Handle, Modifiers, Keysym) + Send + Sync + 'static,
    {
        self.handle.0.lock().unwrap().on_key_release(on_key_release);

        self
    }

    /// Sets callback to call when some event occurs.
    pub fn on_key_event<F>(&mut self, on_key_event: F) -> &mut Self
    where
        F: FnMut(&Handle, KeyEvent) + Send + Sync + 'static,
    {
        self.handle.0.lock().unwrap().on_key_event(on_key_event);

        self
    }

    /// Sets callback to call when the [`KeyGrabber`] starts grabbing input.
    pub fn on_start<F>(&mut self, on_start: F) -> &mut Self
    where
        F: Fn(&Handle) + Send + Sync + 'static,
    {
        self.handle.0.lock().unwrap().on_start(on_start);

        self
    }

    /// Sets callback to call when the [`KeyGrabber`] stops grabbing input.
    pub fn on_stop<F>(&mut self, on_stop: F) -> &mut Self
    where
        F: Fn(&Handle) + Send + Sync + 'static,
    {
        self.handle.0.lock().unwrap().on_stop(on_stop);

        self
    }
}

impl Handle {
    /// Start grabbing input.
    pub fn start(&self) {
        {
            let mut inner = self.0.lock().unwrap();

            if inner.handle.is_some() {
                return;
            }

            self.start_impl(&mut inner);
        }

        self.on_start();
    }

    /// Stop grabbing input.
    pub fn stop(&self) {
        {
            let mut inner = self.0.lock().unwrap();

            if inner.handle.is_some() {
                self.stop_impl(&mut inner);
            } else {
                return;
            }

            inner.paused = false;
        }

        self.on_stop();
    }

    /// Temporarily pause input grabbing.
    pub fn pause(&self) {
        let mut inner = self.0.lock().unwrap();
        if let Some(handle) = &inner.handle
            && let Err(e) = handle.set_keyboard_interactivity(layer::KeyboardInteractivity::None)
        {
            tracing::error!("{e}");
            return;
        }

        inner.paused = true
    }

    /// Restart input grabbing.
    pub fn unpause(&self) {
        let mut inner = self.0.lock().unwrap();
        if let Some(handle) = &inner.handle
            && let Err(e) =
                handle.set_keyboard_interactivity(layer::KeyboardInteractivity::Exclusive)
        {
            tracing::error!("{e}");
            return;
        }

        inner.paused = false;
    }

    /// Whether the [`KeyGrabber`] is running.
    ///
    /// Returns true if the `KeyGrabber` has been started but not yet stopped.
    pub fn running(&self) -> bool {
        self.0.lock().unwrap().handle.is_some()
    }

    /// Create a non non-owning [`WeakHandle`] referring to the same [`KeyGrabber`] state.
    pub fn downgrade(&self) -> WeakHandle {
        WeakHandle(Arc::downgrade(&self.0))
    }

    fn relocate(&self) {
        let mut inner = self.0.lock().unwrap();

        if inner.handle.is_some() {
            self.stop_impl(&mut inner);
            self.start_impl(&mut inner);
        }
    }

    fn start_impl(&self, inner: &mut Inner) {
        let interactivity = if inner.paused {
            layer::KeyboardInteractivity::None
        } else {
            layer::KeyboardInteractivity::Exclusive
        };

        let handle = layer::new_widget(
            KeyGrabberProgram,
            None,
            interactivity,
            layer::ExclusiveZone::Respect,
            layer::ZLayer::Overlay,
        );

        let Ok(handle) = handle else {
            tracing::error!("Could not create a layer to grab inputs.");
            return;
        };

        handle.on_key_event({
            let weak = self.downgrade();
            let weak_data = Arc::downgrade(&inner.callback_data);
            move |_, event: KeyEvent| {
                let Some(grabber) = weak.upgrade() else {
                    return;
                };

                let Some(data) = weak_data.upgrade() else {
                    return;
                };

                let mut data = data.lock().unwrap();

                let captured = event.captured && !data.ignore_capture;

                if !captured {
                    if let Some(on_key_press) = data.on_key_press.as_mut()
                        && event.pressed
                    {
                        on_key_press(&grabber, event.mods, event.key, event.text.clone());
                    } else if let Some(on_key_release) = data.on_key_release.as_mut()
                        && !event.pressed
                    {
                        on_key_release(&grabber, event.mods, event.key);
                    }
                }

                if let Some(on_key_event) = data.on_key_event.as_mut() {
                    on_key_event(&grabber, event)
                }
            }
        });

        inner.handle = Some(handle);
    }

    fn stop_impl(&self, inner: &mut Inner) {
        if let Some(handle) = &inner.handle.take() {
            handle.close();
        }
    }

    fn on_start(&self) {
        let on_start = self.0.lock().unwrap().on_start.clone();
        if let Some(on_start) = on_start {
            on_start(self)
        }
    }

    fn on_stop(&self) {
        let on_stop = self.0.lock().unwrap().on_stop.clone();
        if let Some(on_stop) = on_stop {
            on_stop(self)
        }
    }
}

impl WeakHandle {
    /// Attempts to create a [`Handle`] that refers to the same [`KeyGrabber`].
    ///
    /// Returns [`None`] if the [`KeyGrabber`] has already been dropped.
    pub fn upgrade(&self) -> Option<Handle> {
        self.0.upgrade().map(Handle)
    }
}

impl Inner {
    fn ignore_capture(&mut self, ignore_capture: bool) {
        self.callback_data.lock().unwrap().ignore_capture = ignore_capture;
    }

    fn on_key_press<F>(&mut self, on_key_press: F)
    where
        F: FnMut(&Handle, Modifiers, Keysym, Option<String>) + Send + Sync + 'static,
    {
        self.callback_data.lock().unwrap().on_key_press = Some(Box::new(on_key_press));
    }

    fn on_key_release<F>(&mut self, on_key_release: F)
    where
        F: FnMut(&Handle, Modifiers, Keysym) + Send + Sync + 'static,
    {
        self.callback_data.lock().unwrap().on_key_release = Some(Box::new(on_key_release));
    }

    fn on_key_event<F>(&mut self, on_key_event: F)
    where
        F: FnMut(&Handle, KeyEvent) + Send + Sync + 'static,
    {
        self.callback_data.lock().unwrap().on_key_event = Some(Box::new(on_key_event));
    }

    fn on_start<F>(&mut self, on_start: F)
    where
        F: Fn(&Handle) + Send + Sync + 'static,
    {
        self.on_start = Some(Arc::new(on_start));
    }

    fn on_stop<F>(&mut self, on_stop: F)
    where
        F: Fn(&Handle) + Send + Sync + 'static,
    {
        self.on_stop = Some(Arc::new(on_stop));
    }
}

impl Default for KeyGrabber {
    fn default() -> Self {
        let inner = Inner::default();
        let handle = Handle(Arc::new(Mutex::new(inner)));

        pinnacle_api::output::connect_signal(pinnacle_api::signal::OutputSignal::Focused(
            Box::new({
                let weak = handle.downgrade();
                move |_| {
                    if let Some(handle) = weak.upgrade() {
                        handle.relocate();
                    }
                }
            }),
        ));

        Self { handle }
    }
}

impl Clone for Handle {
    fn clone(&self) -> Self {
        Self(self.0.clone())
    }
}

impl Program for KeyGrabberProgram {
    type Message = ();

    fn view(&self) -> Option<snowcap_api::widget::WidgetDef<Self::Message>> {
        None
    }

    fn update(&mut self, _msg: Self::Message) {}
}
