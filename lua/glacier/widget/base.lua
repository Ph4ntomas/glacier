local signal_table = require("glacier.signal.signal_table")

local widget_signal = require("glacier.widget.signal")

---Widget Base class.
---
---All of Glacier's widget should inherit from this class. It provides methods for signaling,
---rendering, updating and printing the widget.
---@class glacier.widget.Base: glacier.bar.Child
---@field type string Type of widget.
---@field private signals glacier.signal.SignalTable
---@field private widget_id integer
local Base = {
    type = "Base",
}

local widget_id = 0

local function next_id()
    local id = widget_id
    widget_id = widget_id + 1
    return id
end

---Render the widget
---
---@return snowcap.widget.WidgetDef?
function Base:view() end

---Update the widget internal state
---
---@param msg any The message to update the widget with.
---@diagnostic disable-next-line
function Base:update(msg) end

---This function will emit `"widget::redraw_needed"`.
function Base:refresh()
    self:emit(widget_signal.redraw_needed)
end

---Connect a callback to a specific signal.
---
---@param name string The name of the signal you're connecting to.
---@return glacier.signal.SignalHandle
function Base:connect(name, callback)
    return self.signals:connect(name, callback)
end

---Emit a signal.
---
---@param name string Signal to emit
---@param ... any Parameter to sent to the callbacks
function Base:emit(name, ...)
    self.signals:emit(name, ...)
end

---Disconnect a given callback.
---
---@param handle glacier.signal.SignalHandle Handle to the callback to disconnect.
function Base:disconnect(handle)
    self.signals:disconnect(handle)
end

---Disconnect all signal handlers.
function Base:disconnect_all()
    self.signals:disconnect_all()
end

---Get the widget unique id
---@return integer
function Base:id()
    return self.widget_id
end

---Convert the Widget to a printable string.
function Base:__tostring()
    if self.widget_id == nil then
        return ("<class#%s>"):format(tostring(self.type))
    end

    return ("<%s#%d>"):format(tostring(self.type), tostring(self:id()))
end

---Create a new widget class.
---
---@generic Derived:glacier.widget.Base
---@param o self
---@return Derived
function Base:new_class(o)
    o = o or {}

    setmetatable(o, self)
    self.__index = self
    return o
end

---Initialize the superclass.
---
---This method should be called inside the constructor of a derived class.
---@protected
---@generic Derived:self
---@param o Derived Instance of a derived class under construction.
---@return Derived
function Base:super(o)
    o = o or {}

    o.widget_id = next_id()
    o.signals = signal_table()

    setmetatable(o, self)
    self.__tostring = self.__tostring -- Why ? No clue, but it won't work otherwise.
    self.__index = self

    return o
end

return Base --[[@as glacier.widget.Base]]
