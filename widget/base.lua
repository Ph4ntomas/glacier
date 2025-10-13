local signal_table = require("glacier.signal.signal_table")

---@class glacier.widget.Base
---@field private signals glacier.signal.SignalTable
---@field private widget_id integer
local Base = {
    type = "Base"
}

local widget_id = 0

local function next_id()
    local id = widget_id
    widget_id = widget_id + 1
    return id
end

---@param name string The name of the signal you're connecting to.
---
---@return glacier.signal.SignalHandle
function Base:connect(name, callback)
    return self.signals:connect(name, callback)
end

---@param name string Signal to emit
---@param ... any Parameter to sent to the callbacks
function Base:emit(name, ...)
    self.signals:emit(name, ...)
end

---@param handle glacier.signal.SignalHandle
function Base:disconnect(handle)
    self.signals:disconnect(handle)
end

function Base:disconnect_all()
    self.signals:disconnect_all()
end

function Base:drop()
    self:emit("widget::dropping")
    self:disconnect_all()
end

---Get the widget unique id
---@return integer
function Base:id()
    return self.widget_id
end

function Base:__tostring()
    return "<" .. self.type .. "#" .. tostring(self.widget_id) .. ">"
end

function Base:new(o)
    o = o or {}

    o.widget_id = next_id()
    o.signals = signal_table()

    setmetatable(o, self)
    self.__index = self
    return o
end

return Base
