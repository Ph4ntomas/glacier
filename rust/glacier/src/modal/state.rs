use std::{
    collections::HashMap,
    sync::{Arc, Mutex},
};

use pinnacle_api::Keysym;
use regex::Regex;
use snowcap_api::input::Modifiers;

use crate::{
    KeyGrabber,
    signal::{Emitter, WithEmitter},
};

pub struct State {
    pub active_mode: String,
    pub sequence: String,
    pub default_mode: String,
    pub stop_mode: String,
    pub grabber: KeyGrabber,
    pub signal_emitter: Emitter,
    pub modes: HashMap<String, Mode>,
}

struct CommandState {
    pattern: Vec<Regex>,
    _mods: Option<Modifiers>,
    handler: super::CommandHandler,
    keep_grab: bool,
}

#[derive(Debug)]
enum MatchResult<'a> {
    NoMatch,
    Partial,
    Total(Vec<&'a str>),
}

pub enum EvalResult<'a> {
    Stop,
    Pending,
    Exec(Command, Vec<&'a str>),
}

pub struct Command {
    state: Arc<Mutex<CommandState>>,
}

pub struct Mode {
    _name: String,
    commands: Vec<Command>,
}

impl State {
    pub fn start(&mut self, mode: Option<String>) {
        let mode = mode.unwrap_or(self.default_mode.clone());

        if mode == self.stop_mode {
            return self.stop();
        }

        self.reset_sequence();

        if !self.modes.contains_key(&mode) {
            panic!("Unknown mode: {}", mode);
        }

        self.active_mode = mode;
        self.grabber.start();
    }

    pub fn stop(&mut self) {
        self.set_active_mode(self.stop_mode.clone());
        self.reset_sequence();

        self.grabber.stop();
    }

    pub fn set_sequence(&mut self, sequence: String) {
        self.sequence = sequence.clone();
    }

    pub fn reset_sequence(&mut self) {
        self.set_sequence(String::default());
    }

    pub fn active(&self) -> bool {
        self.active_mode != self.stop_mode
    }

    fn set_active_mode(&mut self, active_mode: String) {
        self.active_mode = active_mode;
        self.reset_sequence();
    }

    pub fn process_key(&mut self, keysym: Keysym, text: Option<String>) -> String {
        use pinnacle_api::input;

        let mut sequence = std::mem::take(&mut self.sequence);

        if keysym == input::Keysym::BackSpace {
            sequence.pop();
        } else if keysym == input::Keysym::Escape {
            sequence.clear();
        } else if let Some(text) = text {
            sequence.push_str(&text);
        }

        self.set_sequence(sequence.clone());
        sequence
    }

    pub fn get_mode(&self) -> &Mode {
        self.modes
            .get(&self.active_mode)
            .expect("Internal Error: Could not get active mode")
    }
}

impl WithEmitter for State {
    fn with_emitter(&self) -> Emitter {
        self.signal_emitter.clone()
    }
}

impl Mode {
    pub fn merge_with(&mut self, other: &Self) {
        self.commands.append(&mut other.commands.clone());
    }

    pub fn eval_sequence<'a>(&self, sequence: &'a str, mods: Modifiers) -> EvalResult<'a> {
        let mut ret = EvalResult::Stop;

        for command in &self.commands {
            match command.match_sequence(sequence, mods) {
                MatchResult::Total(v) => return EvalResult::Exec(command.clone(), v),
                MatchResult::Partial => {
                    ret = EvalResult::Pending;
                }
                _ => {}
            }
        }

        ret
    }
}

impl Command {
    fn match_sequence<'a>(&self, sequence: &'a str, mods: Modifiers) -> MatchResult<'a> {
        self.state.lock().unwrap().match_sequence(sequence, mods)
    }

    pub fn call(&self, handle: super::Proxy, captures: Vec<&str>) {
        self.state.lock().unwrap().call(handle, captures)
    }
}

impl CommandState {
    fn match_sequence<'a>(&self, sequence: &'a str, mods: Modifiers) -> MatchResult<'a> {
        let _ = mods; // reserved for future use.

        let mut seq = sequence;

        let mut captures = Vec::new();

        for re in self.pattern.iter() {
            let Some(m) = re.find(seq) else {
                break;
            };

            captures.push(m.as_str());
            seq = seq.split_at(m.end()).1;
        }

        if !seq.is_empty() {
            MatchResult::NoMatch
        } else if captures.len() != self.pattern.len() {
            MatchResult::Partial
        } else {
            MatchResult::Total(captures)
        }
    }

    fn call(&mut self, proxy: super::Proxy, captures: Vec<&str>) {
        if !self.keep_grab {
            proxy.grabber.pause();
        }

        (self.handler)(&proxy, captures);

        if !self.keep_grab {
            proxy.grabber.unpause();
        }
    }
}

impl Clone for Command {
    fn clone(&self) -> Self {
        Self {
            state: self.state.clone(),
        }
    }
}

impl From<super::Command> for Command {
    fn from(value: super::Command) -> Self {
        use super::Command;
        let Command {
            pattern,
            mods,
            handler,
            keep_grab,
        } = value;

        let state = CommandState {
            pattern,
            _mods: mods,
            handler: handler.expect("Command must have a handler."),
            keep_grab,
        };

        Self {
            state: Arc::new(Mutex::new(state)),
        }
    }
}

impl From<super::Mode> for Mode {
    fn from(value: super::Mode) -> Self {
        use super::Mode;

        let Mode { name, commands, .. } = value;

        let commands = commands.into_iter().map(Command::from).collect();

        Self {
            _name: name,
            commands,
        }
    }
}
