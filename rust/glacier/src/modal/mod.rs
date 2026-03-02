//! Modal (VI-like) bindings.
//!
//! [`Modal`] introduces VI-like modal bindings as an alternative way to interact with the
//! compositor.
//!
//! When active, it captures all keyboard inputs, adding them to an internal sequence, and try to
//! match them against the current [`Mode`] [`Command`]. If the sequence can be entirely matched by
//! a `Command` pattern, the `Command` handler is called with the captured input fragment. If the
//! sequence partially matches some patterns, the `Modal` instance will wait for additional input,
//! otherwise, it will discard the current sequence.
//!
//! # Commands
//! A [`Command`] is defined by a pattern (an array of string) to be matched against, and a
//! handler. When the current sequence matches a `Command` pattern, the sequence is consumed and
//! transformed to a [`Vec<&str>`], where each entry correspond to a specific element of the
//! pattern. The command is then called with a [`Proxy`] instance as its first parameter, and the
//! matches as the second. The `Proxy` instance can be used to manage the [`Modal`] state, or
//! interact with the underlying [`KeyGrabber`].
//!
//! By default, the [`KeyGrabber`] is paused while the handler is running, to allow the handler to
//! use Pinnacle API. This is done because focus-based query rely on the keyboard focused, which
//! would be on the `KeyGrabber` otherwise. This behavior can be changed by setting the
//! [`keep_grab`] flag on the command. One reason to do so is if your [`Command`] is meant to
//! change the active mode, as inputs would be ignored until the handler stops and the new-mode
//! take over, instead of being buffered.
//!
//! Example #1 - Set a window fullscreen
//! ```rust
//! use pinnacle_api::window;
//! use glacier::modal;
//! modal::Command::new()
//!     .description("Client toggle Fullscreen")
//!     .pattern(["c", "f"])
//!     .handler(|_, _| {
//!         if let Some(client) = window::get_focused() {
//!             client.toggle_fullscreen();
//!             client.raise();
//!         }
//!     });
//! ```
//!
//! Example #2 - Focus clients in direction, with repetition:
//! ```rust
//! use pinnacle_api::{
//!     window,
//!     util::Direction,
//! };
//! use glacier::modal;
//! modal::Command::new()
//!     .description("Focus Client in a given direction.")
//!     .pattern([r"\d*", "[hjkl]"])
//!     .handler(|_, args| {
//!         let Some(window) = window::get_focused() else {
//!             return;
//!         };
//!
//!         let (count, dir) = match args[..] {
//!             [count, "h"] => (count, Direction::Left),
//!             [count, "j"] => (count, Direction::Down),
//!             [count, "k"] => (count, Direction::Up),
//!             [count, "l"] => (count, Direction::Right),
//!             _ => unreachable!(),
//!         };
//!
//!         let count = count.parse().unwrap_or(1);
//!         let in_dir: Vec<_> = window.in_direction(dir).take(count).collect();
//!
//!         let win = if count >= in_dir.len() {
//!             in_dir.last()
//!         } else {
//!             in_dir.get(count)
//!         };
//!
//!         if let Some(win) = win {
//!             win.set_focused(true);
//!         }
//!     });
//! ```
//!
//! # Modes
//! [`Mode`]s are a named collection of [`Command`]. They are used to group and scope `Command`.
//!
//! When an the sequence is evaluated, only the `Command` from the active `Mode` are taken into
//! account.
//!
//! Some command might be useful in more than one [`Mode`]. Instead of duplicating these in every
//! `Mode` they are meant to be used in, it's possible to define pseudo [`Mode`] which will be
//! merged with other `Mode` during the [`Modal`] initialization, either by calling [`merge`] or
//! [`merge_with`] (which only merges with specific `Mode`).
//!
//! # Modal behavior & Key bindings
//!
//! [`Modal`] aims isn't necessarily to replace bindings, and can be used alongside them. In fact,
//! a keybinding is used to enter the default [`Mode`]. However, care should be taken when both are
//! used, and key binding should pause or stop modal input processing if their action uses
//! focused-based query, or request focus on a specific widget.
//!
//! # Full example
//! ```rust
//! use pinnacle_api::{
//!     input::{ self, Mod },
//!     output,
//!     pinnacle,
//!     process,
//!     tag,
//!     util::Direction,
//!     window,
//! };
//! use snowcap_api::widget::{self as snowcap, Length, row};
//!
//! use glacier::{
//!     bar,
//!     modal::{ self, Mode, Command },
//!     widget::{
//!         self, textbox,
//!     },
//! };
//!
//! const TERMINAL: &str = "alacritty";
//!
//! fn setup_bar(output: output::OutputHandle, modal: modal::ModalHandle) {
//!    let active_mode = modal.active_mode(Some(
//!        widget::TextBox::new()
//!        .style(textbox::default_style()
//!            .bg_color(glacier::color::from_hex("#1a1a1a"))
//!            .pixels(22.0)
//!            .font(
//!                snowcap::font::Font::new()
//!                .family(snowcap::font::Family::Monospace)
//!                .weight(snowcap::font::Weight::Bold)
//!            )
//!            .overrides([
//!                (
//!                    "insert",
//!                    textbox::ContentStyle::new().bg_color(glacier::color::from_hex("#af8700"))
//!                ),
//!                (
//!                    "run",
//!                    textbox::ContentStyle::new().bg_color(glacier::color::from_hex("#d70000"))
//!                ),
//!            ])
//!        )
//!        .view_callback(|content, style| {
//!            let bg_color = style.bg_color;
//!            return Some(row::Row::new_with_children([
//!                    textbox::TextBox::default_view(content.to_uppercase(), style).unwrap(),
//!                ])
//!                .height(Length::Fill)
//!                .into())
//!        })
//!    ));
//!
//!    let bar: bar::Bar<()> = bar::Bar::new()
//!        .first(bar::children![
//!            active_mode,
//!        ])
//!        .last(bar::children![modal.sequence(None)])
//!        .show(Some(output.clone()))
//!    ;
//!
//!    // Store the bar somewhere.
//! }
//!
//! async fn config() {
//!     let mod_key = match pinnacle::backend() {
//!         pinnacle::Backend::Tty => Mod::SUPER,
//!         pinnacle::Backend::Window => Mod::ALT,
//!     };
//!
//!     let modal_bind = if mod_key == Mod::ALT {
//!         input::Keysym::Alt_L
//!     } else {
//!         input::Keysym::Super_L
//!     };
//!
//!     let modal_handle = glacier::modal::modal()
//!         .start_binding(modal_bind)
//!         .modes([
//!             Mode::new("normal")
//!                 .commands([
//!                     Command::new()
//!                         .description("Focus Client in a given direction.")
//!                         .pattern([r"\d*", "[hjkl]"])
//!                         .handler(|_, args| {
//!                             let Some(window) = window::get_focused() else {
//!                                 return;
//!                             };
//!
//!                             let (count, dir) = match args[..] {
//!                                 [count, "h"] => (count, Direction::Left),
//!                                 [count, "j"] => (count, Direction::Down),
//!                                 [count, "k"] => (count, Direction::Up),
//!                                 [count, "l"] => (count, Direction::Right),
//!                                 _ => unreachable!(),
//!                             };
//!
//!                             let count = count.parse().unwrap_or(1);
//!                             let in_dir: Vec<_> = window.in_direction(dir).take(count).collect();
//!
//!                             let win = if count >= in_dir.len() {
//!                                 in_dir.last()
//!                             } else {
//!                                  in_dir.get(count)
//!                             };
//!
//!                             if let Some(win) = win {
//!                                win.set_focused(true);
//!                             }
//!                         }),
//!                     Command::new()
//!                         .description("Client toggle Fullscreen")
//!                         .pattern(["c", "f"])
//!                         .handler(|_, _| {
//!                             if let Some(client) = window::get_focused() {
//!                                 client.toggle_fullscreen();
//!                                 client.raise();
//!                             }
//!                         }),
//!                 ]),
//!             Mode::new("run")
//!                 .commands([
//!                     Command::new()
//!                         .description("Start terminal")
//!                         .pattern(["t"])
//!                         .handler(|cmd, _| {
//!                             process::Command::new(TERMINAL).spawn();
//!                             cmd.stop()
//!                         })
//!                 ]),
//!             Mode::new("common")
//!                 .commands([
//!                     Command::new()
//!                         .description("Enter run mode")
//!                         .pattern(["r"])
//!                         .handler(|cmd, _| cmd.start("run"))
//!                 ])
//!        ])
//!        .init();
//!
//!    let tag_names = ["1", "2", "3", "4", "5", "6", "7", "8", "9"];
//!    output::for_each_output(move |output| {
//!        let mut tags = tag::add(output, tag_names);
//!        tags.next().unwrap().set_active(true);
//!
//!        setup_bar(
//!            output.clone(),
//!            modal_handle.clone(),
//!        );
//!    });
//! }
//!
//! pinnacle_api::main!(config);
//! ```
//!
//! [`keep_grab`]: Command::keep_grab
//! [`merge`]: Mode::merge
//! [`merge_with`]: Mode::merge_with

use std::{
    collections::HashMap,
    sync::{Arc, Mutex, Weak},
};

use pinnacle_api::{
    Keysym,
    input::{Bind, Mod, ToKeysym},
};
use regex::{self, Regex};

use snowcap_api::{
    input::Modifiers,
    signal::{HandlerPolicy, Signal, Signaler},
    widget::message::UniversalMsg,
};

use crate::{KeyGrabber, keygrabber, widget::textbox::TextBox};

mod state;
use state::State;

/// [`Signal`] emitted when the active [`Mode`] changes.
#[derive(Clone, Signal)]
pub struct ModeChanged(pub WeakHandle, pub String);

/// [`Signal`] emitted when the current input sequence changes.
#[derive(Clone, Signal)]
pub struct SequenceChanged(pub WeakHandle, pub String);

/// Proxy object passed to [`Command`] handlers when they are called.
pub struct Proxy {
    grabber: keygrabber::Handle,
    modal: ModalHandle,
}

type CommandHandler = Box<dyn FnMut(&Proxy, Vec<&str>) + Send + Sync + 'static>;

/// Callback to execute when a given pattern is matched.
///
/// See module level [documentation] for more informations.
///
/// [documentation]: self
#[derive(Default)]
pub struct Command {
    pattern: Vec<Regex>,
    mods: Option<Modifiers>,
    handler: Option<CommandHandler>,
    keep_grab: bool,
}

/// [`Mode`] merge policy.
pub enum MergePolicy {
    /// Merge with every regular `Mode`s.
    All,
    /// Merge with a list of `Mode`s
    ByName(Vec<String>),
}

/// Named collection of [`Command`]s.
pub struct Mode {
    pub name: String,
    pub merge: Option<MergePolicy>,
    pub commands: Vec<Command>,
}

/// Owning handle to [`Modal`] state.
#[derive(Clone)]
pub struct ModalHandle {
    state: Arc<Mutex<State>>,
}

/// Non-owning handle to [`Modal`] state.
#[derive(Clone)]
pub struct WeakHandle(Weak<Mutex<State>>);

/// Modal behavior builder type.
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
    /// Define a new [`Command`].
    pub fn new() -> Self {
        Default::default()
    }

    /// Sets the [`Command`] pattern.
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

    /// Sets the [`Command`] handler.
    pub fn handler<F>(self, handler: F) -> Self
    where
        F: FnMut(&Proxy, Vec<&str>) + Send + Sync + 'static,
    {
        Self {
            handler: Some(Box::new(handler)),
            ..self
        }
    }

    /// Sets the [`Command`] description.
    pub fn description(self, description: impl Into<String>) -> Self {
        let _ = description;

        Self { ..self }
    }

    /// Make the [`Command`] keep input grabbing active on execution.
    pub fn keep_grab(self, keep_grab: bool) -> Self {
        Self { keep_grab, ..self }
    }
}

impl Mode {
    /// Create a new [`Mode`]
    pub fn new(name: impl Into<String>) -> Self {
        Self {
            name: name.into(),
            merge: None,
            commands: Vec::new(),
        }
    }

    /// Mark this [`Mode`] as being merged with all regular [`Mode`]s.
    pub fn merge(self) -> Self {
        Self {
            merge: Some(MergePolicy::All),
            ..self
        }
    }

    /// Mark this [`Mode`] as needing to be merged with a set of [`Mode`]s.
    pub fn merge_with<I, S>(self, modes: I) -> Self
    where
        I: IntoIterator<Item = S>,
        S: Into<String>,
    {
        let modes = modes.into_iter().map(S::into).collect();

        Self {
            merge: Some(MergePolicy::ByName(modes)),
            ..self
        }
    }

    /// Sets this [`Mode`]'s [`Command`]s.
    pub fn commands<I>(self, commands: I) -> Self
    where
        I: IntoIterator<Item = Command>,
    {
        let commands = commands.into_iter().collect();

        Self { commands, ..self }
    }

    /// Adds a single [`Command`] to this [`Mode`].
    pub fn push_command(mut self, command: Command) -> Self {
        self.commands.push(command);

        self
    }
}

/// Build and initialize [`ModalHandle`].
impl Modal {
    /// Default [`Mode`] default name
    const DEFAULT_MODE: &str = "normal";
    /// Default stop mode name,
    const DEFAULT_STOP_MODE: &str = "insert";

    /// Create a new [`Modal`] instance.
    pub fn new() -> Self {
        Self::default()
    }

    /// Sets the key to use to start the default [`Mode`].
    pub fn start_binding(&mut self, keysym: impl ToKeysym) -> &mut Self {
        self.start_binding = Some(keysym.to_keysym());
        self
    }

    /// Sets the modifiers to use when registering the key-binding.
    pub fn start_mods(&mut self, mods: Mod) -> &mut Self {
        self.start_mods = Some(mods);
        self
    }

    /// Sets the default mode name.
    pub fn default_mode(&mut self, mode_name: impl Into<String>) -> &mut Self {
        self.default_mode = Some(mode_name.into());
        self
    }

    /// Whether to start the default_mode upon calling [`init`].
    ///
    /// [`init`]: Modal::init
    pub fn deferred_start(&mut self, deferred_start: bool) -> &mut Self {
        self.deferred_start = deferred_start;
        self
    }

    /// Sets the mode name to use when the [`Modal`] is disabled.
    pub fn stop_mode(&mut self, stop_mode: impl Into<String>) -> &mut Self {
        self.stop_mode = Some(stop_mode.into());
        self
    }

    /// Sets all [`Mode`]s in this instance
    pub fn modes<I>(&mut self, modes: I) -> &mut Self
    where
        I: IntoIterator<Item = Mode>,
    {
        self.modes = modes.into_iter().collect();
        self
    }

    /// Push a single [`Mode`] in this instance.
    pub fn mode(&mut self, mode: Mode) -> &mut Self {
        self.modes.push(mode);
        self
    }

    /// Initialize this [`Modal`].
    ///
    /// Returns a [`ModalHandle`] referring to the newly started [`Modal`] state, consuming the
    /// current object.
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

        let signaler = Signaler::new();
        let grabber = KeyGrabber::new();
        let modes = Self::process_modes(modes);

        let state = State {
            active_mode: default_mode.clone(),
            sequence: String::default(),
            default_mode,
            stop_mode,
            grabber,
            signaler,
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
                MergePolicy::All => {
                    for mode in ret.values_mut() {
                        mode.merge_with(to_merge);
                    }
                }
                MergePolicy::ByName(mode_names) => {
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

    pub fn active_mode<Msg>(&self) -> TextBox<Msg>
    where
        Msg: From<UniversalMsg> + Clone + Send + 'static,
    {
        // Lock the state so the active_mode can't change before the textbox is returned.
        let state = self.state.lock().unwrap();
        let text_box = TextBox::with_content(&state.active_mode);

        text_box.connect_with(&state.signaler, |ModeChanged(_, new_mode), handle| {
            let Ok(_) = handle.set_content(new_mode) else {
                return HandlerPolicy::Discard;
            };

            HandlerPolicy::Keep
        });

        text_box
    }

    pub fn sequence<Msg>(&self) -> TextBox<Msg>
    where
        Msg: From<UniversalMsg> + Clone + Send + 'static,
    {
        // Lock the state so the sequence can't change before the textbox is returned.
        let state = self.state.lock().unwrap();
        let text_box = TextBox::with_content(&state.sequence);

        text_box.connect_with(&state.signaler, |SequenceChanged(_, sequence), handle| {
            let Ok(()) = handle.set_content(sequence) else {
                return HandlerPolicy::Discard;
            };

            HandlerPolicy::Keep
        });

        text_box
    }

    fn emit<S>(&self, sig: S)
    where
        S: Signal,
    {
        let signaler = self.state.lock().unwrap().signaler();
        signaler.emit(sig);
    }

    fn mode_change(&self) {
        let (mode, seq) = {
            let state = self.state.lock().unwrap();
            (state.active_mode.clone(), state.sequence.clone())
        };

        self.emit(SequenceChanged(self.downgrade(), seq));
        self.emit(ModeChanged(self.downgrade(), mode));
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
            self.emit(SequenceChanged(self.downgrade(), sequence));
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

        let sequence = self.state.lock().unwrap().sequence.clone();
        self.emit(SequenceChanged(self.downgrade(), sequence));
    }
}

impl WeakHandle {
    /// Attempt to upgrade this `WeakHandle` to a [`ModalHandle`].
    ///
    /// Returns [`None`] if the `ModalHandle` has already been dropped.
    pub fn upgrade(&self) -> Option<ModalHandle> {
        self.0.upgrade().map(|state| ModalHandle { state })
    }
}

impl Proxy {
    /// Start a specific [`Mode`], by name.
    pub fn start(&self, mode: impl Into<String>) {
        self.modal.start(mode);
    }

    /// Starts the default [`Mode`].
    pub fn start_default(&self) {
        self.modal.start_default();
    }

    /// Stop handling input, and enter the stop mode.
    pub fn stop(&self) {
        self.modal.stop();
    }

    /// Access the underlying [`KeyGrabber`] handle.
    pub fn grabber(&self) -> &keygrabber::Handle {
        &self.grabber
    }
}

/// Create a new [`Modal`].
pub fn modal() -> Modal {
    Default::default()
}
