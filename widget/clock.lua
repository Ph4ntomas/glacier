local Widget = require("snowcap.widget")

local Base = require("glacier.widget.base")
local widget_signal = require("glacier.widget.signal")

local timer = require("glacier.utils.timer")

---glacier.widget.clock module.
---
---@class glacier.widget.clock
---@field mt metatable This module metatable.
---@overload fun(...: glacier.widget.clock.Config): glacier.widget.clock.Clock
local clock = { mt = {} }

---A simple date/time widget.
---
---@class glacier.widget.clock.Clock: glacier.widget.Base
---@field format string Format string to call os.date with.
---@field content string String representing the current time.
local Clock = Base:new({ type = "Clock" })

function Clock:view()
    ---@diagnostic disable-next-line:redefined-local
    local clock = Widget.container({
        height = Widget.length.Fill,
        width = Widget.length.Shrink,
        valign = Widget.alignment.CENTER,
        child = Widget.text({
            text = self.content,
        }),
    })

    return clock
end

---@diagnostic disable-next-line:unused-local
function Clock:update(_msg) end

function Clock:refresh()
    self.content = tostring(os.date(self.format))
    self:emit(widget_signal.redraw_needed)
end

function Clock:__tostring()
    return ("<%s#%d>"):format(self.type, self:id())
end

---Configuration options for `glacier.widget.clock.Clock`
---
---@class glacier.widget.clock.Config
---@field format? string Format string to call os.date with

function Clock:new(config)
    config = config or {}

    local format = config.format or "%a. %d %b. %H:%M"

    ---@diagnostic disable-next-line:redefined-local
    local clock = {
        format = format,
        content = tostring(os.date(format)),
    }

    setmetatable(clock, self)
    self.__index = self

    clock.timer = timer({
        interval = config.refresh or 30,
        callback = function()
            clock:refresh()
        end,
    })

    clock.timer:start()

    return clock
end

function clock.mt:__call(...)
    return Clock:new(...)
end

---@diagnostic disable-next-line:param-type-mismatch
return setmetatable(clock, clock.mt)
