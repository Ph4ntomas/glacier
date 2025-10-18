local Process = require("pinnacle.process")
local Widget = require("snowcap.widget")

local Base = require("glacier.widget.base")
local widget_signal = require("glacier.widget.signal")

---Internal prompt module.
local _prompt = {}

---glacier.widget.prompt module.
---
---@class glacier.widget.prompt
---@field mt metatable This module metatable.
---@overload fun(...:glacier.widget.prompt.Config):glacier.widget.Prompt
local prompt = { mt = {} }

---Action to execute on an update
---
---@class glacier.widget.prompt.MessageAction
---@field action glacier.widget.prompt.Action
---@field value? string

---Type of action to execute on an update.
---
---@enum glacier.widget.prompt.Action
_prompt.Action = {
    INPUT = "prompt::input",
    SUBMIT = "prompt::submit",

    ---@type fun(value: string): glacier.widget.prompt.MessageAction
    Input = function(value)
        return { action = _prompt.Action.INPUT, value = value }
    end,
    ---@type fun(): glacier.widget.prompt.MessageAction
    Submit = function()
        return { action = _prompt.Action.SUBMIT }
    end,
}

---A simple prompt to run some commands.
---
---@class glacier.widget.Prompt: glacier.widget.Base
---@field placeholder string The prompt placeholder.
---@field font snowcap.widget.Font Font used to render the text.
---@field padding snowcap.widget.Padding
---@field height snowcap.widget.Length
---@field width snowcap.widget.Length
---@field icon snowcap.widget.text_input.Icon
---@field style snowcap.widget.text_input.Styles
---@field exe_callback fun(command: string) Function to run on submit.
---@field private active boolean Whether this prompt is active
---@field private prompt string What to display at the start of the prompt
local Prompt = Base:new_class({ type = "Prompt" })

---Whether the prompt is currently active.
---
---@return boolean
function Prompt:is_active()
    return self.active
end

---Create the view for this prompt.
---
---If the `Prompt` is not active, nil is return.
---@return snowcap.widget.WidgetDef|nil
function Prompt:view()
    if not self.active then
        return
    end

    ---@diagnostic disable-next-line:redefined-local
    local prompt = Widget.container({
        height = self.height,
        width = self.width,
        valign = Widget.alignment.CENTER,
        child = Widget.text_input({
            value = self.content,
            placeholder = self.placeholder,
            id = tostring(self),
            callbacks = {
                on_input = function(value)
                    return { widget_id = self:id(), action = _prompt.Action.Input(value) }
                end,
                on_submit = { widget_id = self:id(), action = _prompt.Action.Submit() },
            },
            padding = self.padding,
            font = self.font,
            icon = self.icon,
            style = self.style,
        }),
    })

    return prompt
end

---Activate this `Prompt`
---
---This function instruct the parent `Layer` to re-render, then to focus this Prompt.
function Prompt:activate()
    if self.active then
        return
    end

    self.active = true
    self:refresh()
    self:focus()
end

---Make this prompt emit a signal to inform the Layer to re-render.
function Prompt:refresh()
    self:emit(widget_signal.redraw_needed)
end

---Focus this prompt.
function Prompt:focus()
    self:emit(widget_signal.request_focus, tostring(self))
end

---Unfocus this prompt.
function Prompt:unfocus()
    self:emit(widget_signal.request_unfocus)
end

---Deactivate this prompt.
---
---When called, this function flush the prompt content, and make it hidden.
function Prompt:deactivate()
    self:reset()
    self.active = false

    self:emit(widget_signal.redraw_needed)
end

---Reset the prompt content.
function Prompt:reset()
    self.content = ""
end

---Update this Prompt internal state.
---
---@param msg any
function Prompt:update(msg)
    local focusable = require("glacier.widget.operation").focusable

    if not msg then
        return
    end

    if msg.operation == focusable.UNFOCUS then
        self:deactivate()
    end

    if msg.widget_id == self:id() then
        ---@diagnostic disable-next-line:redefined-local
        local msg = msg.action --[[@as glacier.widget.prompt.MessageAction]]

        if msg.action == _prompt.Action.INPUT then
            self.content = msg.value
        elseif msg.action == _prompt.Action.SUBMIT then
            self.exe_callback(self.content)

            self:unfocus()
        end
    end
end

---Configuration options for `glacier.widget.prompt.Prompt`.
---
---@class glacier.widget.prompt.Config
---@field placeholder? string The prompt placeholder text.
---@field font? snowcap.widget.Font Font to use to render text & placeholder.
---@field icon? snowcap.widget.text_input.Icon|string Icon to display.
---@field style? snowcap.widget.text_input.Style Main style for this prompt.
---@field style_focus? snowcap.widget.text_input.Style Style to use when the prompt is in focus.
---@field padding? snowcap.widget.Padding Internal padding to apply to the input.
---@field height? snowcap.widget.Length Height of the input surrounding container.
---@field width? snowcap.widget.Length Width of the input surrounding container.
---@field exe_callback? fun(input: string) Callback to call when the prompt is submitted.

---Construct a `glacier.widget.Prompt`.
---
---@param config glacier.widget.prompt.Config
---@return glacier.widget.Prompt
function Prompt:new(config)
    ---@diagnostic disable-next-line: redefined-local
    local config = config or {}

    ---@type glacier.widget.Prompt
    ---@diagnostic disable-next-line:missing-fields,redefined-local
    local prompt = Prompt:super({
        placeholder = config.placeholder,
        font = config.font,
        icon = config.icon --[[@as snowcap.widget.text_input.Icon]],
        padding = config.padding,
        height = config.height,
        width = config.width,
        style = {
            active = config.style,
            focused = config.style_focus or config.style,
        },
        exe_callback = config.exe_callback,
        active = false,
        content = "",
    })

    return prompt
end

---Default prompt execution callback.
---
---@param command string
function prompt.spawn(command)
    if command and command ~= "" then
        Process.spawn(command)
    end
end

--- Create a prompt widget which will launch a command when submitted.
---
---@param config glacier.widget.prompt.Config
---@return glacier.widget.Prompt
function prompt.mt:__call(config)
    ---@diagnostic disable-next-line redefined-local
    local config = config or {}

    if type(config.icon) == "string" then
        local code_point = utf8.codepoint(config.icon --[[@as string]])
        config.icon = {
            code_point = code_point,
        }
    end

    ---@type glacier.widget.prompt.Config
    local default_config = {
        name = "",
        placeholder = "",
        font = {
            family = Widget.font.family.Monospace,
            weight = Widget.font.weight.SEMIBOLD,
        },
        icon = {
            code_point = utf8.codepoint(""),
            spacing = 4.0,
        },
        style = {
            background = Widget.background.Color(Widget.color.from_rgba(0, 0, 0, 0)),
            border = { width = 0 },
        },
        padding = { top = 0, bottom = 0 },
        height = Widget.length.Fill,
        width = Widget.length.Fill,
        exe_callback = prompt.spawn,
    }

    ---@diagnostic disable-next-line:redefined-local
    local config = require("glacier.utils").merge_table(default_config, config)

    return Prompt:new(config)
end

---@diagnostic disable-next-line: param-type-mismatch
return setmetatable(prompt, prompt.mt)
