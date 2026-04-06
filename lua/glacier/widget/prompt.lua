local Widget = require("snowcap.widget")
local StdSig = require("snowcap.widget.signal")

local color = require("glacier.misc.color")

---Glacier's Prompts
---
---@class glacier.widget.prompt
---@field mt metatable The module's metatable
---
---@overload fun(...: glacier.widget.prompt.Config): glacier.widget.Prompt
local prompt = { mt = {} }

----------------------
-- Type Definitions --
----------------------

---Signals emitted by Prompts.
---
---@enum glacier.widget.prompt.signal
local _signal = {
    DONE = "glacier::widget::prompt::done",
}

---Function called when the Prompt is submitted.
---@alias glacier.widget.prompt.ExeCallback fun(input: string)

---Prompt's events
---@class glacier.widget.prompt.Event
---@field activate? {}
---@field deactivate? {}
---@field focus? {}
---@field input? string
---@field submit? {}

---Prompt's messages.
---@class glacier.widget.prompt.Message
---@field id integer
---@field event glacier.widget.prompt.Event
local Message = {}

---Prompt's input area appearance
---@class glacier.widget.prompt.InputStyle
---Color used to render text.
---@field fg_color? snowcap.widget.Color
---Background color used for the prompt
---@field bg_color? snowcap.widget.Color
---Border for the Prompt's text_input
---@field border? snowcap.widget.Border
---Color used to render the icon
---@field icon_color? snowcap.widget.Color
---Color used for the placeholder text
---@field placeholder_color? snowcap.widget.Color
---Color used for selected text
---@field selection_color? snowcap.widget.Color

---Prompt widget style.
---@class glacier.widget.prompt.Style: glacier.widget.prompt.InputStyle
---Font used to render the prompt
---@field font? snowcap.widget.Font
---Icon to display on the left or right side of the Prompt
---@field icon? snowcap.widget.text_input.Icon
---Prompt's internal padding
---@field padding? snowcap.widget.Padding
---Style overrides for active Prompt.
---@field active? glacier.widget.prompt.InputStyle
---Style overrides for focused Prompt.
---@field focused? glacier.widget.prompt.InputStyle
local Style = {}

---Prompt's configuration.
---@class glacier.widget.prompt.Config
---@field placeholder? string
---@field style? glacier.widget.prompt.Style
---@field on_exe? glacier.widget.prompt.ExeCallback

---Prompt widget.
---
---@class glacier.widget.Prompt: snowcap.widget.Program
---@field placeholder string
---@field on_exe glacier.widget.prompt.ExeCallback
---@field private _style glacier.widget.prompt.Style
---@field private _content string
---@field private _id string
---@field private _active boolean
local Prompt = setmetatable({}, { __index = require("snowcap.widget.base").Base })

----------------------
-- Module functions --
----------------------

function prompt.default_view() end

---Default `Prompt` appearance.
---
---@param style? glacier.widget.prompt.Style
---@return glacier.widget.prompt.Style
function prompt.default_style(style)
    ---@type glacier.widget.prompt.Style
    return require("glacier.utils").merge_table({
        font = {
            family = Widget.font.family.Monospace,
            weight = Widget.font.weight.SEMIBOLD,
        },
        icon = {
            code_point = utf8.codepoint(""),
            spacing = 4.0,
        },
        bg_color = color.from_hex("#000000", 0.0),
        border = {
            width = 0.0,
        },
        padding = { bottom = 0., left = 0., right = 0., top = 0. },
    }, style)
end

---Default prompt execution callback.
---
---This function split the string on whitespace, then call Process::spawn on the resulting
---array.
---
---Spawn a new process.
---@param input string
function prompt.spawn(input)
    if not input or string.len(input) == 0 then
        return
    end

    local cmd = {}

    for word in string.gmatch(input, "[^%s]+") do
        table.insert(cmd, word)
    end

    if #cmd == 0 then
        return
    end

    require("pinnacle.process").spawn(cmd)
end

-----------------------
-- Message functions --
-----------------------

---@package
---Build a focus message
---
---@param id integer
---@return glacier.widget.prompt.Message
function Message.focus(id)
    ---@type glacier.widget.prompt.Message
    return {
        id = id,
        event = {
            focus = {},
        },
    }
end

---@package
---Build an activate message
---
---@param id integer
---@return glacier.widget.prompt.Message
function Message.activate(id)
    ---@type glacier.widget.prompt.Message
    return {
        id = id,
        event = {
            activate = {},
        },
    }
end

---@package
---Build a deactivate message
---
---@param id integer
---@return glacier.widget.prompt.Message
function Message.deactivate(id)
    ---@type glacier.widget.prompt.Message
    return {
        id = id,
        event = {
            deactivate = {},
        },
    }
end

---@package
---Build an input message.
---
---@param id integer
---@param input string
---@return glacier.widget.prompt.Message
function Message.input(id, input)
    ---@type glacier.widget.prompt.Message
    return {
        id = id,
        event = {
            input = input,
        },
    }
end

---@package
---Build a submit message.
---
---@param id integer
---@return glacier.widget.prompt.Message
function Message.submit(id)
    ---@type glacier.widget.prompt.Message
    return {
        id = id,
        event = {
            submit = {},
        },
    }
end

-------------------
-- Style methods --
-------------------

---@package
---
---@param input_style glacier.widget.prompt.InputStyle
---@return snowcap.widget.text_input.Style
local function _to_textinput_style(input_style)
    ---@type snowcap.widget.text_input.Style
    return {
        background = input_style.bg_color and Widget.background.Color(input_style.bg_color) or nil,
        border = input_style.border,
        icon = input_style.icon_color,
        placeholder = input_style.icon_color,
        selection = input_style.selection_color,
        value = input_style.fg_color,
    }
end

---@private
function Style:get_active()
    local deep_copy = require("snowcap.util").deep_copy
    local merge_table = require("glacier.utils").merge_table

    ---@type glacier.widget.prompt.InputStyle
    local style = deep_copy({
        fg_color = self.fg_color,
        bg_color = self.bg_color,
        border = self.border,
        icon_color = self.icon_color,
        placeholder_color = self.placeholder_color,
        selection_color = self.selection_color,
    })

    if self.active then
        style = merge_table(style, deep_copy(self.active))
    end

    return _to_textinput_style(style)
end

---@private
function Style:get_focused()
    local deep_copy = require("snowcap.util").deep_copy
    local merge_table = require("glacier.utils").merge_table

    ---@type glacier.widget.prompt.InputStyle
    local style = deep_copy({
        fg_color = self.fg_color,
        bg_color = self.bg_color,
        border = self.border,
        icon_color = self.icon_color,
        placeholder_color = self.placeholder_color,
        selection_color = self.selection_color,
    })

    if self.focused then
        style = merge_table(style, deep_copy(self.focused))
    end

    return _to_textinput_style(style or {})
end

---@package
---
---@return snowcap.widget.text_input.Styles
function Style:to_textinput()
    ---@type snowcap.widget.text_input.Styles
    return {
        active = self:get_active(),
        focused = self:get_focused(),
        -- If the UI take too much time to refresh, iced sets the input as disabled, which doesn't look good.
        disabled = self:get_active(),
    }
end

--------------------
-- Style lifetime --
--------------------

---@package
---
---Initialize a new `Style`
---@param style glacier.widget.prompt.Style
---@return glacier.widget.prompt.Style
function Style.new(style)
    style = style or {}
    return setmetatable(style, { __index = Style })
end

---------------------------
-- Prompt public methods --
---------------------------

function Prompt:focus()
    self:emit(StdSig.send_message, Message.focus(self:id()))
end

function Prompt:activate()
    self:emit(StdSig.send_message, Message.activate(self:id()))
end

function Prompt:deactivate()
    self:emit(StdSig.send_message, Message.deactivate(self:id()))
end

----------------------------
-- Prompt private methods --
----------------------------

function Prompt:on_focus()
    if not self._active then
        return
    end

    self:emit(StdSig.operation, Widget.operation.focusable.Focus(self._id))
end

function Prompt:on_activate()
    if self._active then
        return
    end

    self._active = true
    self:on_focus()
end

function Prompt:on_deactivate()
    if not self._active then
        return
    end

    self._content = ""
    self._active = false
    self:emit(_signal.DONE, tostring(self))
end

---@private
---Extract an event from the message.
---
---@param msg any|glacier.widget.prompt.Message?
---@return glacier.widget.prompt.Event?
function Prompt:get_message_event(msg)
    if msg and msg.id == self:id() then
        return msg.event
    end

    return nil
end

function Prompt:__tostring()
    return ("<Prompt#%d>"):format(self:id())
end

---------------------------------
-- impl snowcap.widget.Program --
---------------------------------

---Creates a widget definition for display by Snowcap.
---
---A widget may return nil to notify its parent program that it has
---nothing to display. It's up to the parent to decide whether to display a
---placeholder or to remove the widget from the tree.
---@return snowcap.widget.WidgetDef?
function Prompt:view()
    if not self._active then
        return nil
    end

    local ti = Widget.text_input({
        id = self._id,
        placeholder = self.placeholder or "",
        value = self._content or "",
        padding = self._style.padding,
        font = self._style.font,
        icon = self._style.icon,
        style = self._style:to_textinput(),
        on_input = function(input)
            return Message.input(self:id(), input)
        end,
        on_submit = Message.submit(self:id()),
    })

    return Widget.container({
        child = ti,
        height = Widget.length.Fill,
        width = Widget.length.Fill,
        valign = Widget.alignment.CENTER,
    })
end

---Updates this widget program with the received message.
---@param msg any|glacier.widget.prompt.Message
function Prompt:update(msg)
    local event = self:get_message_event(msg)

    if not event then
        return
    end

    if event.activate then
        self:on_activate()
    elseif event.deactivate then
        self:on_deactivate()
    elseif event.focus then
        self:on_focus()
    elseif event.input then
        self._content = event.input
    elseif event.submit then
        if self.on_exe then
            self.on_exe(self._content)
        else
            prompt.spawn(self._content)
        end

        self:on_deactivate()
    end
end

---Called when a surface has been created with this program.
---
---A surface handle is provided to allow the program to manupulate
---the surface. This handle should be passed to any child programs
---to allow them to use it as well.
---
---@param event snowcap.widget.SurfaceEvent
function Prompt:event(event)
    if event.focus_lost then
        self:on_deactivate()
    end
end

-----------
-- Other --
-----------

---Create a new Prompt widget.
---
---@param config glacier.widget.prompt.Config
---@return glacier.widget.Prompt
function Prompt:new(config)
    config = config or {}
    config.style = require("glacier.utils").merge_table(prompt.default_style(), config.style)

    local base = require("snowcap.widget.base").Base.new()
    local ret = setmetatable(base, {
        __index = Prompt,
        __tostring = Prompt.__tostring,
    }) --[[@as glacier.widget.Prompt]]

    ret._content = ""
    ret.placeholder = config.placeholder
    ret.on_exe = config.on_exe
    ret._style = Style.new(config.style)
    ret._id = tostring(ret)
    ret._active = false

    return ret
end

---Create a new Prompt widget.
---
---@param ... glacier.widget.prompt.Config
---@return glacier.widget.Prompt
function prompt.mt:__call(...)
    return Prompt:new(...)
end

prompt.Prompt = Prompt
prompt.signal = _signal

---@diagnostic disable-next-line:param-type-mismatch
return setmetatable(prompt, prompt.mt) --[[@as glacier.widget.prompt]]
