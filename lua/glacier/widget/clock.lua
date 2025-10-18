local Widget = require("snowcap.widget")

local Base = require("glacier.widget.base")
local widget_signal = require("glacier.widget.signal")
local timer = require("glacier.utils.timer")

---glacier.widget.clock module.
---
---@class glacier.widget.clock: glacier.widget.Base
---@field mt metatable This module metatable.
---
---@overload fun(...: glacier.widget.clock.Config): glacier.widget.clock.Clock
local clock = { mt = {} }

---A simple date/time widget.
---
---The widget periodically calls `os.date()` with a user-defined format. The period can be changed
---if a shorter period is to be used.
---
---@see glacier.widget.clock.Config for more information about the default config.
---
---@class glacier.widget.clock.Clock: glacier.widget.Base
---@field format string Format string to call os.date with.
---@field content string String representing the current time.
---@field style? snowcap.widget.text.Style Style to apply to the clock's widget.
local Clock = Base:new_class({ type = "Clock" })

---Create the view for this clock.
---
---@return snowcap.widget.WidgetDef
function Clock:view()
    ---@diagnostic disable-next-line:redefined-local
    local clock = Widget.container({
        height = Widget.length.Fill,
        width = Widget.length.Shrink,
        valign = Widget.alignment.CENTER,
        child = Widget.text({
            text = self.content,
            style = self.style,
        }),
    })

    return clock
end

---Refresh the clock.
---
function Clock:refresh()
    self.content = tostring(os.date(self.format))
    self:emit(widget_signal.redraw_needed)
end

---Configuration options for `glacier.widget.clock.Clock`.
---
---@class glacier.widget.clock.Config
---@field format? string Format string to call os.date with. Default: "%a. %d %b. %H:%M"
---@field refresh? number Amount of time to wait before refreshing the clock (in second). Default: 30
---@field style? snowcap.widget.text.Style Style to apply to the clock's text.

---Create a new Clock.
---@param config glacier.widget.clock.Config
---@return glacier.widget.clock.Clock
function Clock:new(config)
    config = config or {}

    local format = config.format or "%a. %d %b. %H:%M"

    ---@diagnostic disable-next-line:redefined-local
    local clock = Clock:super({
        format = format,
        content = tostring(os.date(format)),
        style = config.style,
    })

    clock.timer = timer.started({
        interval = config.refresh or 30,
        callback = function()
            clock:refresh()
        end,
    })

    return clock
end

---Create a `Clock` widget.
function clock.mt:__call(...)
    return Clock:new(...)
end

clock.Clock = Clock

---@diagnostic disable-next-line:param-type-mismatch
return setmetatable(clock, clock.mt)
