local Log = require("pinnacle.log")

local textbox = require("glacier.widget.textbox")
local keygrabber = require("glacier.keygrabber")

---glacier.modal module.
---
---This module introduces modal behavior to Pinnacle.
---
---It works by capturing all inputs while active, and checking whether it matches the current
---sequence.
---If a total match is found, the associated `glacier.pinnacle.Command`'s handler is execute, and
---the sequence is reset.
---If at least a Command has a partial match, we wait for further input.
---If no partial matches are found, the current sequence is treated as invalid and reset.
---
---## Commands
---A `Command` is defined as a pattern (an array strings) to be matched against, and a handler.
---When every string in the `Command`'s `pattern` match the current sequence, the handler is called
---with every matching substring passed as a parameter. This allow the handler to take decision
---based on what matched exactly.
---
---The command handlers always receive as their first parameter an object representing the Command
---itself. This object additionally have a few functions to change mode, stop processing input, and
---access the underlying keygrabber.
---
---### Examples:
---Define a command that switch to the tag N position to the left or right of the current tag:
---```lua
---{
---    pattern = { "%d*", "[HL]" },
---    handler = function(_, count, direction)
---        count = count == '' and 1 or tonumber(count)
---        dir = dir == 'H' and -1 or 1
---
---        --- pseudo function to rotate active tags by a given amount.
---        shift_tag(count * dir)
---    end
---}
---```
---
---## Mode
---A `Mode` is a named array of commands. When processing inputs, only the current mode's `Command`s
---are taken into account.
---
---Since some commands might need to be shared between modes (e.g. to switch between mode, start
---some prompts, etc.), some pseudo-modes can be defined by setting a `merge` field on them. If
---this field contains a boolean, the Mode will be merged into every other non-mergeable mode. If
---the field is a string array, it's interpreted as the name of the mode it should be merged into.
---
---## Interaction with Key bindings
---
---`glacier.modal` doesn't try to replace bindings entirely, and in fact register a keybinding to
---enter the `default_mode`. However, bindings are processed by Pinnacle before any key is sent to
---the keygrabber, so care should be taken when using both at the same time, since `glacier.modal`
---will not be aware of state changes due to key bindings. As an example, if super is used to enter
---the default mod, and `super+p` opens a prompt, it's possible to have the prompt open without the
---ability for it to receive inputs since they are grabbed by `glacier.modal`.
---
---As a general rule of thumb, you should not use the same modifier for your bindings and
---`glacier.modal`, unless you've ensured you bindings are modified to override `glacier.modal`
---behavior if needed.
---
---## Full Example
---Here is a sample configuration:
---```lua
---local Pinnacle = require("pinnacle")
---local Input = require("pinnacle.input")
---local Output = require("pinnacle.output")
---local Tag = require("pinnacle.tag")
---
---local Glacier = require("glacier")
---local modal = require("glacier.modal")
---
---local function shift_tags(amount)
---    [...]
---end
---
---local function setup_glacier(output)
---    Glacier.output(output).prompt = Glacier.widget.prompt()
---
---    Glacier.bar({
---        first = {
---            modal.active_mode,
---            [...]
---        },
---        center = {
---            Glacier.output(output).prompt,
---        },
---        last = {
---            modal.sequence,
---            [...]
---        },
---        output = output
---    })
---end
---
---Pinnacle.setup(function()
---    modal.init({
---        start_binding = mod_key == "alt" and Input.key.Alt_L or Input.key.Super_L,
---        modes = {
---            normal = {
---                {
---                    pattern = { "%d*",  "[gHL]" },
---                    description = "Move to a tag in a given direction",
---                    handler = function(_, count, mvt)
---                        local nomvt = count == ''
---                        count = count == '' and 1 or tonumber(count)
---                        if mvt == 'g' and not nomvt then
---                            local output = Output.get_focused()
---                            if not output then
---                                return
---                            end
---                            local tags = output:tags()
---
---                            if count > 0 and count <= #tags then
---                                tags[count]:switch_to()
---                            end
---                        elseif mvt == 'H' then
---                            shift_tags(-count)
---                        else
---                            shift_tags(count)
---                        end
---                    end
---                },
---            },
---            run = {
---                {
---                    pattern = { 't' },
---                    description = "Start terminal",
---                    handler = function(cmd)
---                        Process.spawn(terminal)
---                        cmd:stop()
---                    end
---                },
---            },
---            common = {
---                merge = true,
---                {
---                    pattern = { 'r' },
---                    description = "Enter run mode",
---                    handler = function(self) self:start("run") end
---                },
---                {
---                    pattern = { 'i' },
---                    description = "Enter insertion mode",
---                    handler = function(self) self:stop() end
---                },
---                {
---                    pattern = { ':' },
---                    description = "Start prompt",
---                    handler = function(cmd)
---                        cmd:stop()
---                        Glacier.output().prompt:activate()
---                    end
---                }
---            }
---        }
---    })
---
---    glacier.bar
---end
---```
---
---@class glacier.modal
---@field mt metatable module metatable.
---@field active_mode glacier.widget.textbox.TextBox TextBox displaying the current active_mode.
---@field sequence glacier.widget.textbox.TextBox TextBox displaying the current sequence of input.
---
---@overload fun(glacier.modal.Config)
local modal = { mt = {} }

---@package
---Holds the current sequence.
---
---When this object is updated, `glacier.modal.sequence` content is set.
---@class glacier.modal.Sequence
---@field content string Current string of input.
local _sequence = {
    content = "",
}

---Add a character at the end of the sequence.
---@param char string Character to append to the sequence.
function _sequence:push(char)
    self:set(self.content .. char)
end

---Remove the character at the end of the sequence.
function _sequence:pop()
    if #self.content > 0 then
        local offset = utf8.offset(self.content, -1)

        self:set(string.sub(self.content, 1, offset - 1))
    end
end

---Empty the sequence.
function _sequence:reset()
    self:set("")
end

---@private
---Set the sequence content.
---
---This function additionally set the content of `glacier.modal.sequence`.
---@param content string
function _sequence:set(content)
    self.content = content
    modal.sequence:set(self.content)
end

---Returns the sequence content.
---
---@return string
function _sequence:get()
    return self.content
end

---@package
---Holds the current mode name.
---
---When this object is updated, it in turn update `glacier.modal.active_mode`.
---@class glacier.modal.ActiveMode
local _active_mode = {
    mode = "",
}

---Sets the current mode.
function _active_mode:set(mode)
    self.mode = mode
    modal.active_mode:set(mode)
end

---Retrieve the current mode name.
function _active_mode:get()
    return self.mode
end

---@package
---
---Internal state for `glacier.modal`
---@class (exact) glacier.modal._modal
---@field sequence glacier.modal.Sequence Current sequence
---@field active_mode glacier.modal.ActiveMode Active mode name.
---@field keygrabber glacier.keygrabber.KeyGrabber KeyGrabber used by `glacier.modal`
---@field default_mode string Name of the default mode.
---@field stop_mode string Name of the pseudo mode used when input processing is stopped.
---@field modes table<string, glacier.modal.Mode> Modes for input processing.
---@field mt metatable
local _modal = {
    ---Current sequence of character.
    sequence = _sequence,
    active_mode = _active_mode,
    modes = {},
}

---Evaluate the current sequence.
---
---Iterate over the current Mode's `glacier.modal.Command`s. If a command match, its handler is
---called with every captures.
---
---@param sequence string Current input sequence.
---@param modifiers snowcap.input.Modifiers Current set of modifiers.
---@param mode glacier.modal.Mode Active mode.
local function eval_sequence(sequence, modifiers, mode)
    assert(mode, "Fatal error: expected Mode, got nil")

    local done = true

    for _, command in ipairs(mode) do
        local valid, finished, captures = command:match(sequence, modifiers)

        if finished then
            command:run(table.unpack(captures))
            return true
        elseif valid then
            done = false
        end
    end

    return done
end

---KeyGrabber.on_key_press callback.
---
---Everytime a key is received by the KeyGrabber, it's passed to this function.
---
---If BackSpace was pressed, the last character of the sequence is removed. If the key code is a
---displayable character, it's added to the sequence.
---
---@param _ glacier.keygrabber.KeyGrabber The KeyGrabber.
---@param mods snowcap.input.Modifiers A set of active modifier.
---@param key snowcap.Key The key that was pressed.
---@param text string? Printable character associated with the key pressed.
local function process_key(_, mods, key, text)
    -- When we're stopping, the additional inputs might be flushed toward this function.
    local active_mode = _modal.active_mode:get()

    if active_mode == _modal.stop_mode then
        return
    end

    local Input = require("snowcap.input")

    if key == Input.key.BackSpace then
        _modal.sequence:pop()
    elseif key == Input.key.Escape then
        _modal.sequence:reset()
        return
    elseif text then
        _modal.sequence:push(text)
    end

    local mode = _modal.modes[active_mode]

    if not mode then
        Log.error("Unknown mode: " .. active_mode)
        return
    end

    if eval_sequence(_modal.sequence:get(), mods, _modal.modes[_modal.active_mode:get()]) then
        _modal.sequence:reset()
    end

    modal.sequence:set(_modal.sequence:get())
end

---Leave the current mode, and stop processing input.
---
---Calling this function will stop input processing, reset the sequence, and set the active mode
---to `stop_mode`.
local function stop()
    _modal.active_mode:set(_modal.stop_mode)
    _modal.sequence:reset()

    _modal.keygrabber:stop()
end

---Start processing inputs.
---
---Upon being called with nil, or a valid mode name, this function changes the active mode,
---reset the current sequence, and start the keygrabber if it wasn't already running.
---
---If the function is called with the `stop_mode` name, `stop()` is called instead.
---
---@param mode? string Mode to enter. If nil or missing, the default mode is used instead.
local function start(mode)
    mode = mode or _modal.default_mode

    if mode == _modal.stop_mode then
        stop()
    end

    if _modal.modes[mode] == nil then
        Log.error(("Invalid mode '%s'"):format(mode))
        return
    end

    _modal.active_mode:set(mode)
    _modal.sequence:reset()

    _modal.keygrabber:start()
end

---Command to execute when the sequence matches a specified pattern.
---
---@class glacier.modal.Command
---@field pattern string[] Pattern to match.
---@field handler fun(cmd: glacier.modal.Command, ...) Command's handler.
---@field keep_grab? boolean Unless true, input grabbing is paused while the handler is running.
local Command = {}

---Create a new Command.
---
---@param command glacier.modal.Command
---@return glacier.modal.Command
function Command:new(command)
    command = command or {}

    assert(
        type(command.handler) == "function",
        ("Invalid callback. Expected 'function', got '%s'"):format(type(command.handler))
    )

    setmetatable(command, self)
    self.__index = self
    return command
end

---Switch active Mode.
---
---This function changes `glacier.modal` active mode, replacing the current one.
---
---@param mode string Name of the mode to switch to.
function Command:start(mode)
    start(mode)
end

---Stop processing inputs.
function Command:stop()
    stop()
end

---Match the sequence against the Command's pattern
---
---@param sequence string Sequence to match the pattern against.
---@param modifiers snowcap.input.Modifiers
---@return boolean # True if the sequence is valid for this command.
---@return boolean # True if the sequence completely match the command.
---@return string[] # Captured fragment, one per sub pattern.
---@diagnostic disable-next-line:unused-local --TODO: Support modifiers
function Command:match(sequence, modifiers)
    local matches = nil
    local captures = {}

    for idx, item in ipairs(self.pattern) do
        sequence, matches = string.gsub(sequence, "^" .. item, function(capture)
            table.insert(captures, capture)
            return ""
        end)

        if matches == 0 or (#sequence > 0 and idx == #self.pattern) then
            return false, false, {}
        elseif #sequence == 0 and idx < #self.pattern then
            return true, false, {}
        end
    end

    return true, true, captures
end

---Returns `glacier.modal` keygrabber.
---
---This function allows access to `glacier.modal` keygrabber. It's useful if you need to
---temporarily stop processing inputs, without changing the active mode.
---
---@return glacier.keygrabber.KeyGrabber
function Command:grabber()
    return _modal.keygrabber
end

---Execute the Command handler.
---
---Unless `keep_grab` is true, the KeyGrabber will be paused while the command is running. This is
---done so the API works properly when working with `focus`. If keep_grab is true, function
---querying focused window or output might fail due to the focus being on the invisible layer.
---
---You should not rely on the KeyGrabber being paused if you want to stop it temporarily and do so
---explicitly by calling stop/start functions.
---
---@param ... string String captured from the pattern.
function Command:run(...)
    if not self.keep_grab then
        self:grabber():pause()
    end

    local ok, err = pcall(function(...)
        self:handler(...)
    end, ...)

    if not ok then
        Log.error("Error while calling command handler: " .. tostring(err))
    end

    if not self.keep_grab then
        self:grabber():unpause()
    end
end

---Collection of command.
---
---@class glacier.modal.Mode
---@field name? string
---@field merge? string[]|boolean If present, mark the mode as needing to be merged.
---@field [integer] glacier.modal.Command glacier.modal.Command collection.
local Mode = {}

---Initialize the mode.
---
---@param name string
---@param mode glacier.modal.Mode
---@return glacier.modal.Mode
function Mode:new(name, mode)
    mode = mode or {} --[[ @as glacier.modal.Mode ]]

    for k, cmd in ipairs(mode) do
        mode[k] = Command:new(cmd)
    end

    mode.name = name
    setmetatable(mode, self)
    self.__index = self
    return mode
end

---Merge a `glacier.modal.Mode` into the current one.
---
---This function appends every `glacier.modal.Command` from a given mode into self.
---@param other glacier.modal.Mode
function Mode:merge_with(other)
    for _, cmd in ipairs(other) do
        table.insert(self, cmd)
    end
end

---@package
---Process `glacier.modal.Config` modes.
---
---This function iterate over every mode definition in the table, turning them into proper mode
---objects.
---
---It then merge every mode with the `merge` attribute with their target.
---@param mode_table table<string, glacier.modal.Mode>
---@return table<string, glacier.modal.Mode>
local function process_modes(mode_table)
    ---@type table<string, glacier.modal.Mode>
    local processed = {}
    local modenames = {}

    local to_merge = {}

    for k, v in pairs(mode_table) do
        local mode = Mode:new(k, v)

        if mode.merge ~= nil then
            to_merge[k] = mode
        else
            table.insert(modenames, k)
            processed[k] = mode
        end
    end

    for _, mode in pairs(to_merge) do
        local names = type(mode.merge) == "table" and mode.merge or modenames

        for _, name in ipairs(names) do
            if processed[name] ~= nil then
                processed[name]:merge_with(mode)
            end
        end
    end

    return processed
end

---This class is used to completely override the keybinding used to start `glacier.modal`.
---@class glacier.modal.KeyBind
---@field mods pinnacle.input.Mod[] Modifiers to pass to `pinnacle.input.keybind()`
---@field key pinnacle.input.Key|string Key to be bound.

---`glacier.modal` configuration options.
---@class glacier.modal.Config
---@field start_binding? pinnacle.input.Key|string|glacier.modal.KeyBind Key to press to enter the default_mode.
---@field default_mode? string Name of the default mode.
---@field stop_mode? string Name of the pseudo mode where we stop processing inputs.
---@field deferred_start? boolean If true, don't start the default mode at the end of initialization.
---@field modes table<string, glacier.modal.Mode> A collection of modes.

---Initialize `glacier.modal`.
---
---### Deferring start
---By default, `glacier.modal` starts the default mode at the end of this function. This behavior
---can be changed by setting `deferred_start` in the config.
---
---### Setting the binding
---By default, `glacier.modal` will use `Pinnacle.input.key.Super_L` as an activation keybind. This
---can be changed by setting `start_binding`.
---
---If config.start_binding, is a `pinnacle.input.Key` or a `string`, all mods are ignored, which
---allow entering the default key by hitting a modifier key. If it's a `glacier.modal.KeyBind`
---instead, the mods and key of that object will be used when creating the key binding.
---
---@param config glacier.modal.Config
function modal.init(config)
    local Input = require("pinnacle.input")

    config = config or {}

    ---@type glacier.modal.Config
    local default_config = {
        start_binding = Input.key.Super_L,
        default_mode = "normal",
        stop_mode = "insert",
        deferred_start = false,
        modes = {},
    }

    config = require("glacier.utils").merge_table(default_config, config)

    _modal.stop_mode = config.stop_mode
    _modal.default_mode = config.default_mode
    _modal.modes = process_modes(config.modes)

    _modal.keygrabber = keygrabber({
        on_key_press = process_key,
    })

    modal.active_mode = textbox({})
    modal.sequence = textbox({})

    local keybind_mods = {
        "ignore_shift",
        "ignore_ctrl",
        "ignore_alt",
        "ignore_super",
        "ignore_iso_level3_shift",
        "ignore_iso_level5_shift",
    }

    local keybind_key = config.start_binding

    if type(config.start_binding) == "table" then
        local bind = config.start_binding --[[ @as glacier.modal.KeyBind ]]

        keybind_mods = bind.mods
        config.start_key = bind.key
    end

    Input.keybind({
        mods = keybind_mods,
        key = keybind_key,
        on_press = function()
            start(_modal.default_mode)
        end,
        group = "Glacier",
        description = "Start modal input grabbing.",
    })

    if not config.deferred_start then
        start(config.default_mode)
    end
end

function modal.mt:__call(...)
    return modal.init(...)
end

modal.start = start
modal.stop = start

---@diagnostic disable-next-line: param-type-mismatch
return setmetatable(modal, modal.mt) --[[ @as glacier.modal ]]
