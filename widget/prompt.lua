local Process = require("pinnacle.process")
local Log = require("pinnacle.log")
local Widget = require("snowcap.widget")

--local Experimental = require("pinnacle.experimental")

local Base = require("glacier.widget.base")
local widget_signal = require("glacier.widget.signal")

---@class glacier.widget.PromptConfig

---@class glacier.widget.Prompt: glacier.widget.Base
---@field private active boolean Whether this prompt is active
---@field private prompt string What to display at the start of the prompt
---@field private name string?
local Prompt = Base:new { type = "Prompt" }

---Whether the prompt is currently active
---@return boolean
function Prompt:is_active()
    return self.active
end

function Prompt:view()
    --Log.warn(tostring(self) .. ": view(). active = " .. tostring(self.active) .. " content= " .. self.content)
    if not self.active then
        return
    end

    local prompt = Widget.row({
        item_alignment = Widget.alignment.START,
        spacing = 0,
        height = Widget.length.Fill,
        width = Widget.length.Fill,
        children = {
            Widget.text({
                text = self.prompt,
                valign = Widget.alignment.CENTER,
                height = Widget.length.Fill,
            }),
            Widget.container({
                height = Widget.length.Fill,
                valign = Widget.alignment.CENTER,
                child = Widget.text_input({
                    value = self.content,
                    placeholder = "",
                    id = tostring(self),
                    callbacks = {
                        on_input = function(value)
                            return { widget_id = self:id(), action = "input", value = value }
                        end,
                        on_submit = { widget_id = self:id(), action = "submit" }
                    },
                })
            })
        }
    })

    return prompt
end

function Prompt:activate()
    if self.active then
        return
    end

    self.active = true
    self:refresh()
    self:focus()
end

function Prompt:refresh()
    self:emit(widget_signal.redraw_needed)
end

function Prompt:focus()
    Log.warn("focusing:", self)
    self:emit(widget_signal.request_focus, tostring(self))
end

function Prompt:deactivate()
    self:reset()
    self.active = false

    self:emit(widget_signal.redraw_needed)
end

function Prompt:reset()
    self.content = ""
end

function Prompt:update(msg)
    if not msg then
        return
    end

    if msg.type == "unfocus" then
        self:deactivate()
    end

    if msg.widget_id ~= self:id() then
        return
    end

    if msg.action == "input" then
        Log.warn("update: INPUT " .. tostring(msg.value))
        self.content = msg.value
    end

    if msg.action == "submit" then
        if #self.content ~= 0 then
            Process.spawn(self.content)
        end

        self.content = ""
    end
end

function Prompt:__tostring()
    if self.name then
        return "<" .. self.type .. "#" .. tostring(self:id()) .. "#" .. self:name() .. ">"
    else
        return "<" .. self.type .. "#" .. tostring(self:id()) .. ">"
    end
end

function Prompt:new(config)
    ---@diagnostic disable-next-line: redefined-local
    local config = config or {}

    local prompt = {
        name = config.name,
        active = false,
        prompt = config.prompt or ": ",
        content = "",
    }

    Base:new(prompt)

    setmetatable(prompt, self)
    self.__index = self

    return prompt
end


local function prompt(config)
    return Prompt:new(config)
end

return prompt
