use std::sync::{Arc, Mutex, Weak};

use xkbcommon::xkb::Keysym;

use snowcap_api::{
    input::{KeyEvent, Modifiers},
    layer::{self, LayerHandle},
    widget::Program,
};

pub struct KeyGrabberProgram;

#[derive(Default)]
pub struct KeyCallbackData {
    ignore_capture: bool,
    on_key_press:
        Option<Box<dyn FnMut(&Handle, Modifiers, Keysym, Option<String>) + Send + Sync + 'static>>,
    on_key_release: Option<Box<dyn FnMut(&Handle, Modifiers, Keysym) + Send + Sync + 'static>>,
    on_key_event: Option<Box<dyn FnMut(&Handle, KeyEvent) + Send + Sync + 'static>>,
}

#[derive(Default)]
pub struct Inner {
    handle: Option<LayerHandle<()>>,
    callback_data: Arc<Mutex<KeyCallbackData>>,
    on_start: Option<Arc<dyn Fn(&Handle) + Send + Sync + 'static>>,
    on_stop: Option<Arc<dyn Fn(&Handle) + Send + Sync + 'static>>,
}

#[derive(Default)]
pub struct Handle(Arc<Mutex<Inner>>);

struct WeakHandle(Weak<Mutex<Inner>>);

#[derive(Default)]
pub struct KeyGrabber {
    handle: Handle,
}

impl KeyGrabber {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn start(&self) -> Handle {
        self.handle.start();

        Handle(self.handle.0.clone())
    }

    pub fn stop(&self) {
        self.handle.stop();
    }

    pub fn pause(&self) {
        self.handle.pause();
    }

    pub fn unpause(&self) {
        self.handle.unpause();
    }

    pub fn handle(&self) -> Handle {
        Handle(self.handle.0.clone())
    }

    pub fn ignore_capture(&mut self, ignore_capture: bool) -> &mut Self {
        self.handle.0.lock().unwrap().ignore_capture(ignore_capture);

        self
    }

    pub fn on_key_press<F>(&mut self, on_key_press: F) -> &mut Self
    where
        F: FnMut(&Handle, Modifiers, Keysym, Option<String>) + Send + Sync + 'static,
    {
        self.handle.0.lock().unwrap().on_key_press(on_key_press);

        self
    }

    pub fn on_key_release<F>(&mut self, on_key_release: F) -> &mut Self
    where
        F: FnMut(&Handle, Modifiers, Keysym) + Send + Sync + 'static,
    {
        self.handle.0.lock().unwrap().on_key_release(on_key_release);

        self
    }

    pub fn on_key_event<F>(&mut self, on_key_event: F) -> &mut Self
    where
        F: FnMut(&Handle, KeyEvent) + Send + Sync + 'static,
    {
        self.handle.0.lock().unwrap().on_key_event(on_key_event);

        self
    }

    pub fn on_start<F>(&mut self, on_start: F) -> &mut Self
    where
        F: Fn(&Handle) + Send + Sync + 'static,
    {
        self.handle.0.lock().unwrap().on_start(on_start);

        self
    }

    pub fn on_stop<F>(&mut self, on_stop: F) -> &mut Self
    where
        F: Fn(&Handle) + Send + Sync + 'static,
    {
        self.handle.0.lock().unwrap().on_stop(on_stop);

        self
    }
}

impl Handle {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn start(&self) {
        if self.running() {
            return;
        }

        let handle = layer::new_widget(
            KeyGrabberProgram,
            None,
            layer::KeyboardInteractivity::Exclusive,
            layer::ExclusiveZone::Respect,
            layer::ZLayer::Overlay,
        );

        let Ok(handle) = handle else {
            //TODO: log error
            return;
        };

        handle.on_key_event({
            let weak = self.downgrade();
            let weak_data = Arc::downgrade(&self.0.lock().unwrap().callback_data);
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

        self.0.lock().unwrap().handle = Some(handle);

        self.on_start()
    }

    pub fn stop(&self) {
        if let Some(handle) = &self.0.lock().unwrap().handle {
            handle.close();
        } else {
            return;
        }

        self.on_stop();
    }

    pub fn pause(&self) {
        if let Some(handle) = &self.0.lock().unwrap().handle {
            let _ = handle.set_keyboard_interactivity(layer::KeyboardInteractivity::None);
            //TODO: Log Error.
        }
    }

    pub fn unpause(&self) {
        if let Some(handle) = &self.0.lock().unwrap().handle {
            let _ = handle.set_keyboard_interactivity(layer::KeyboardInteractivity::Exclusive);
            //TODO: Log Error.
        }
    }

    pub fn running(&self) -> bool {
        self.0.lock().unwrap().handle.is_some()
    }

    fn downgrade(&self) -> WeakHandle {
        WeakHandle(Arc::downgrade(&self.0))
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
    fn upgrade(&self) -> Option<Handle> {
        self.0.upgrade().map(|arc| Handle(arc))
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

impl Program for KeyGrabberProgram {
    type Message = ();

    fn view(&self) -> snowcap_api::widget::WidgetDef<Self::Message> {
        use snowcap_api::widget::{self, row::Row};

        Row::new()
            .height(widget::Length::Fixed(1.0))
            .width(widget::Length::Fixed(1.0))
            .into()
    }

    fn update(&mut self, _msg: Self::Message) {}
}
