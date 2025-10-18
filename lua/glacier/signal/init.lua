---Global signal table
local signal_table = require("glacier.signal.signal_table")()

---@class glacier.signal
local Signal = {
    new_table = require("glacier.signal.signal_table"),
}

--- Register a new callback for a given signal
---
---@param name string Signal to connect to
---@param callback fun(...):boolean? Callback to be called on emit.
---
---@return glacier.signal.SignalHandle
function Signal.connect(name, callback)
    return signal_table:connect(name, callback)
end

--- Send a signal to every registered handlers
---
--- @param name string Signal to emit
--- @param ... any Parameter to send to the callbacks
function Signal.emit(name, ...)
    signal_table:emit(name, ...)
end

--- Disconnect the callback managed by a handle
---
--- @param handle glacier.signal.SignalHandle
function Signal.disconnect(handle)
    handle:disconnect()
end

return Signal
