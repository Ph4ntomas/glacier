use std::{
    collections::HashMap,
    sync::{Arc, Mutex, Weak},
};

use pinnacle_api::{
    Keysym,
    input::{Bind, Mod, ToKeysym},
};
use regex::{self, Regex};
use snowcap_api::input::Modifiers;

use crate::{
    KeyGrabber, keygrabber,
    signal::{Emitter, HandlerPolicy, Signal, WithEmitter},
    widget::TextBox,
};

mod state;
use state::State;

#[derive(Clone, Signal)]
pub struct ModeChanged(WeakHandle);

#[derive(Clone, Signal)]
pub struct SequenceChanged(WeakHandle);

pub struct Proxy {
    grabber: keygrabber::Handle,
    modal: ModalHandle,
}

type CommandHandler = Box<dyn FnMut(&Proxy, Vec<&str>) + Send + Sync + 'static>;

#[derive(Default)]
pub struct Command {
    pub pattern: Vec<Regex>,
    pub mods: Option<Modifiers>,
    pub handler: Option<CommandHandler>,
    pub keep_grab: bool,
}

pub enum MergeMode {
    All,
    ByName(Vec<String>),
}

pub struct Mode {
    pub name: String,
    pub merge: Option<MergeMode>,
    pub commands: Vec<Command>,
}

#[derive(Clone)]
pub struct ModalHandle {
    state: Arc<Mutex<State>>,
}

#[derive(Clone)]
pub struct WeakHandle(Weak<Mutex<State>>);

#[derive(Default)]
pub struct Modal {
    start_binding: Option<Keysym>,
    start_mods: Option<Mod>,
    default_mode: Option<String>,
    stop_mode: Option<String>,
    deferred_start: bool,
    modes: Vec<Mode>,
}

impl Command {
    pub fn new() -> Self {
        Default::default()
    }

    pub fn pattern<I, S>(self, pattern: I) -> Self
    where
        I: IntoIterator<Item = S>,
        S: AsRef<str>,
    {
        let pattern = pattern
            .into_iter()
            .map(|s| Regex::new(s.as_ref()).unwrap())
            .collect();

        Self { pattern, ..self }
    }

    pub fn handler<F>(self, handler: F) -> Self
    where
        F: FnMut(&Proxy, Vec<&str>) + Send + Sync + 'static,
    {
        Self {
            handler: Some(Box::new(handler)),
            ..self
        }
    }

    pub fn description(self, description: impl Into<String>) -> Self {
        let _ = description;

        Self { ..self }
    }

    pub fn keep_grab(self, keep_grab: bool) -> Self {
        Self { keep_grab, ..self }
    }
}

impl Mode {
    pub fn new(name: impl Into<String>) -> Self {
        Self {
            name: name.into(),
            merge: None,
            commands: Vec::new(),
        }
    }

    pub fn merge(self) -> Self {
        Self {
            merge: Some(MergeMode::All),
            ..self
        }
    }

    pub fn merge_with<I, S>(self, modes: I) -> Self
    where
        I: IntoIterator<Item = S>,
        S: Into<String>,
    {
        let modes = modes.into_iter().map(S::into).collect();

        Self {
            merge: Some(MergeMode::ByName(modes)),
            ..self
        }
    }

    pub fn commands<I>(self, commands: I) -> Self
    where
        I: IntoIterator<Item = Command>,
    {
        let commands = commands.into_iter().collect();

        Self { commands, ..self }
    }

    pub fn push_command(mut self, command: Command) -> Self {
        self.commands.push(command);

        self
    }
}

impl Modal {
    const DEFAULT_MODE: &str = "normal";
    const DEFAULT_STOP_MODE: &str = "insert";

    pub fn new() -> Self {
        Self::default()
    }

    pub fn start_binding(&mut self, keysym: impl ToKeysym) -> &mut Self {
        self.start_binding = Some(keysym.to_keysym());
        self
    }

    pub fn start_mods(&mut self, mods: Mod) -> &mut Self {
        self.start_mods = Some(mods);
        self
    }

    pub fn default_mode(&mut self, mode_name: impl Into<String>) -> &mut Self {
        self.default_mode = Some(mode_name.into());
        self
    }

    pub fn deferred_start(&mut self, deferred_start: bool) -> &mut Self {
        self.deferred_start = deferred_start;
        self
    }

    pub fn stop_mode(&mut self, stop_mode: impl Into<String>) -> &mut Self {
        self.stop_mode = Some(stop_mode.into());
        self
    }

    pub fn modes<I>(&mut self, modes: I) -> &mut Self
    where
        I: IntoIterator<Item = Mode>,
    {
        self.modes = modes.into_iter().collect();
        self
    }

    pub fn mode(&mut self, mode: Mode) -> &mut Self {
        self.modes.push(mode);
        self
    }

    pub fn init(&mut self) -> ModalHandle {
        let Modal {
            start_binding,
            default_mode,
            start_mods,
            stop_mode,
            deferred_start,
            modes,
        } = std::mem::take(self);

        let start_binding = start_binding.unwrap_or(pinnacle_api::input::Keysym::Super_L);
        let start_mods = start_mods.unwrap_or(Self::default_start_mods());
        let default_mode = default_mode.unwrap_or(Self::DEFAULT_MODE.into());
        let stop_mode = stop_mode.unwrap_or(Self::DEFAULT_STOP_MODE.into());

        let signal_emitter = Emitter::new();
        let grabber = KeyGrabber::new();
        let modes = Self::process_modes(modes);

        let state = State {
            active_mode: default_mode.clone(),
            sequence: String::default(),
            default_mode,
            stop_mode,
            grabber,
            signal_emitter,
            modes,
        };

        let handle = ModalHandle {
            state: Arc::new(Mutex::new(state)),
        };

        handle.state.lock().unwrap().grabber.on_key_press({
            let weak_handle = handle.downgrade();
            move |grabber, mods, keysym, text| {
                let Some(handle) = weak_handle.upgrade() else {
                    return;
                };

                handle.process_key(grabber, mods, keysym, text);
            }
        });

        pinnacle_api::input::keybind(start_mods, start_binding)
            .group("Glacier")
            .description("Start modal input grabbing.")
            .on_press({
                let handle = handle.clone();
                move || {
                    handle.start_default();
                }
            });

        if deferred_start {
            handle.stop();
        } else {
            handle.start_default();
        }

        handle
    }

    fn process_modes(modes: Vec<Mode>) -> HashMap<String, state::Mode> {
        let (standard, mergeable): (Vec<_>, _) = modes
            .into_iter()
            .map(|mut m| {
                let merge = std::mem::take(&mut m.merge);

                (merge, m.name.clone(), state::Mode::from(m))
            })
            .partition(|(merge, _, _)| merge.is_none());

        let mut ret: HashMap<String, state::Mode> = standard
            .into_iter()
            .map(|(_, name, mode)| (name, mode))
            .collect();

        mergeable
            .iter()
            .for_each(|(merge, _, to_merge)| match merge.as_ref().unwrap() {
                MergeMode::All => {
                    for mode in ret.values_mut() {
                        mode.merge_with(to_merge);
                    }
                }
                MergeMode::ByName(mode_names) => {
                    for name in mode_names {
                        if let Some(mode) = ret.get_mut(name) {
                            mode.merge_with(to_merge);
                        }
                    }
                }
            });

        for (_, name, mode) in mergeable.into_iter() {
            ret.entry(name).or_insert(mode);
        }

        ret
    }

    fn default_start_mods() -> Mod {
        Mod::IGNORE_ALT
            | Mod::IGNORE_CTRL
            | Mod::IGNORE_SHIFT
            | Mod::IGNORE_SUPER
            | Mod::IGNORE_ISO_LEVEL3_SHIFT
            | Mod::IGNORE_ISO_LEVEL5_SHIFT
    }
}

impl ModalHandle {
    fn mode_change(&self) {
        self.emit(SequenceChanged(self.downgrade()));
        self.emit(ModeChanged(self.downgrade()));
    }

    pub fn start(&self, mode: impl Into<String>) {
        self.state.lock().unwrap().start(Some(mode.into()));

        self.mode_change();
    }

    pub fn start_default(&self) {
        self.state.lock().unwrap().start(None);

        self.mode_change();
    }

    pub fn stop(&self) {
        self.state.lock().unwrap().stop();

        self.mode_change();
    }

    pub fn downgrade(&self) -> WeakHandle {
        WeakHandle(Arc::downgrade(&self.state))
    }

    pub fn active_mode<Msg>(&self, text_box: Option<TextBox<Msg>>) -> TextBox<Msg>
    where
        Msg: Send + 'static,
    {
        // Lock the state so the active_mode can't change before the textbox is returned.
        let mut state = self.state.lock().unwrap();
        let mut text_box = text_box.unwrap_or_default();

        text_box.set(&state.active_mode);

        state.connect({
            let weak = text_box.downgrade();

            move |ModeChanged(hndl)| {
                if let Some(mut text_box) = weak.upgrade() {
                    let handle = hndl.upgrade().unwrap();
                    let new_mode = handle.state.lock().unwrap().active_mode.clone();

                    text_box.set(new_mode);

                    HandlerPolicy::Keep
                } else {
                    HandlerPolicy::Discard
                }
            }
        });

        text_box
    }

    pub fn sequence<Msg>(&self, text_box: Option<TextBox<Msg>>) -> TextBox<Msg>
    where
        Msg: Send + 'static,
    {
        // Lock the state so the sequence can't change before the textbox is returned.
        let mut state = self.state.lock().unwrap();
        let mut text_box = text_box.unwrap_or_default();

        text_box.set(&state.sequence);

        state.connect({
            let weak = text_box.downgrade();

            move |SequenceChanged(hndl)| {
                if let Some(mut text_box) = weak.upgrade() {
                    let handle = hndl.upgrade().unwrap();
                    let new_seq = handle.state.lock().unwrap().sequence.clone();
                    text_box.set(new_seq);

                    HandlerPolicy::Keep
                } else {
                    HandlerPolicy::Discard
                }
            }
        });

        text_box
    }

    fn process_key(
        &self,
        grabber: &keygrabber::Handle,
        mods: Modifiers,
        keysym: Keysym,
        text: Option<String>,
    ) {
        if !self.state.lock().unwrap().active() {
            return;
        }

        let sequence = self.state.lock().unwrap().process_key(keysym, text);

        if sequence.is_empty() {
            self.emit(SequenceChanged(self.downgrade()));
            return;
        }

        let v = if let Ok(mut state) = self.state.lock() {
            let mode = state.get_mode();

            match mode.eval_sequence(&sequence, mods) {
                state::EvalResult::Stop => {
                    state.reset_sequence();
                    None
                }
                state::EvalResult::Pending => {
                    state.set_sequence(sequence);
                    None
                }
                state::EvalResult::Exec(cmd, args) => {
                    state.reset_sequence();
                    Some((cmd, args))
                }
            }
        } else {
            panic!("Could not lock state");
        };

        if let Some((command, args)) = v {
            let p = Proxy {
                grabber: grabber.clone(),
                modal: self.clone(),
            };

            command.call(p, args);
        }

        self.emit(SequenceChanged(self.downgrade()));
    }
}

impl Proxy {
    pub fn start(&self, mode: impl Into<String>) {
        self.modal.start(mode);
    }

    pub fn start_default(&self) {
        self.modal.start_default();
    }

    pub fn stop(&self) {
        self.modal.stop();
    }

    pub fn grabber(&self) -> &keygrabber::Handle {
        &self.grabber
    }
}

impl WeakHandle {
    pub fn upgrade(&self) -> Option<ModalHandle> {
        self.0.upgrade().map(|state| ModalHandle { state })
    }
}

impl WithEmitter for ModalHandle {
    fn with_emitter(&self) -> Emitter {
        self.state.lock().unwrap().with_emitter()
    }
}

pub fn modal() -> Modal {
    Default::default()
}
