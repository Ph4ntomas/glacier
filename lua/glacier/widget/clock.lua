local Widget = require("snowcap.widget")
local timer = require("glacier.utils.timer")

---Clock's view function.
---@alias glacier.widget.clock.ViewFn fun(text: string, style: snowcap.widget.text.Style): snowcap.widget.WidgetDef

---glacier.widget.clock module
---
---@class glacier.widget.clock: snowcap.widget.Program
---@field mt metatable The module metatable.
---
---@overload fun(...: glacier.widget.clock.Config): glacier.widget.Clock
local clock = { mt = {} }

----------------------
-- Type Definitions --
----------------------

---Configuration option for `glacier.widget.Clock`.
---
---@class glacier.widget.clock.Config
---Format String to call os.date with.
---
---Defaults to "%a. %d %b. %H %M"
---@field format? string
---Time to wait between clock refresh (in seconds).
---
---Defaults to 30
---@field period? number
---@field style? snowcap.widget.text.Style Style to apply to the clock's text.
---@field view_fn? glacier.widget.clock.ViewFn Render function.

---A simple date/time widget.
---
---The widget periodically calls `os.date()` with a user-defined format.
---
---@class glacier.widget.Clock: snowcap.widget.Program, snowcap.widget.base.Base
---@field format string Format string to call os.date with
---@field style snowcap.widget.text.Style Style to apply to the clock's widget.
---@field view_fn? glacier.widget.clock.ViewFn Optional view override.
---@field timer glacier.timer.Timer Refresh timer.
local Clock = setmetatable({}, { __index = require("snowcap.widget.base").Base })

----------------------
-- Module functions --
----------------------

---Default view function for `Clock`.
---
---@param content string
---@param style snowcap.widget.text.Style
---@return snowcap.widget.WidgetDef
function clock.default_view(content, style)
    return Widget.container({
        height = Widget.length.Fill,
        width = Widget.length.Shrink,
        valign = Widget.alignment.CENTER,
        child = Widget.text({
            text = content,
            height = Widget.length.Fill,
            valign = Widget.alignment.CENTER,
            style = style,
        }),
    })
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
function Clock:view()
    local view_fn = self.view_fn or clock.default_view
    local content = tostring(os.date(self.format))

    return view_fn(content, self.style)
end

---Updates this widget program with the received message.
---@param _ any
function Clock:update(_) end

---Called when a surface has been created with this program.
---
---A surface handle is provided to allow the program to manupulate
---the surface. This handle should be passed to any child programs
---to allow them to use it as well.
---
---@param event snowcap.widget.SurfaceEvent
function Clock:event(event)
    if event.created then
        self.timer:start(false)
    end
end

-----------
-- Other --
-----------

---Creates a new Clock.
---@param config glacier.widget.clock.Config
function Clock:new(config)
    local format = "%a. %d %b. %H:%M"

    ---@type glacier.widget.clock.Config
    config = require("glacier.utils").merge_table({
        format = format,
        period = 30,
    }, config)

    local base = require("snowcap.widget.base").Base.new()
    local ret = setmetatable(base, { __index = Clock })

    ---@cast ret glacier.widget.Clock

    ret.format = config.format
    ret.style = config.style
    ret.view_fn = config.view_fn

    ret.timer = timer({
        interval = config.period,
        signaler = ret:signaler(),
        on_timeout = function(_)
            ret:emit(require("snowcap.widget.signal").redraw_needed)
        end,
    })

    return ret
end

---Creates a new Clock.
---
---@param ... glacier.widget.clock.Config
---@return glacier.widget.Clock
function clock.mt:__call(...)
    return Clock:new(...)
end

clock.Clock = Clock

---@diagnostic disable-next-line:param-type-mismatch
return setmetatable(clock, clock.mt) --[[@as glacier.widget.clock]]
