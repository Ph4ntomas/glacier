local emitter = require("glacier.signal.emitter")

---Utilities for synchronous signalling.
---
---Glacier provides a way to send informations between types in the form of signals. This can
---be used to notify other object of property changes, and is used heavily by Glacier's
---`widgets` to notify the underlying Layer (e.g. `Bar`) that it need to be re-rendered.
---
---## Signals
---
---Signals are arbitrary messages identified by a string.
---
---## Signal Emitter
---
---The `Emitter` type provides a building block to implement signalling. Other types can register
---callback by calling `Emitter:connect`, and dispatch signals to any connected callback by calling
---`Emitter:emit`.
---
---## Emitting Signals
---
---Calling `Emitter:emit` will dispatch the signal to every connected handler for that signal.
---Signal dispatch is synchronous, and should be done without holding locks whenever possible.
---
---## Signal handler
---
---Signal handlers are simple callbacks that receive every parameter except the signal name.
---Handlers can be registered by calling `Emitter:connect`, which
---returns a `Handle` to disconnect the signal later on. Handlers return a `HandlerPolicy` to
---indicate whether they should be kept, or can be discarded (e.g. because the handler is not
---useful anymore, or should fire only once, or would extent the lifetime of another object).
---@class glacier.signal
local signal = {
    Emitter = emitter.Emitter,
    HandlerPolicy = emitter.HandlerPolicy,
}

---Create a new Emitter.
---
---@param o any
---@return glacier.signal.Emitter
function signal.emitter(o)
    return signal.Emitter:new(o)
end

---Global emitter
local global_emitter = signal.emitter()

--- Register a new callback for a given signal
---
---@param name string Signal to connect to
---@param callback fun(...): glacier.signal.HandlerPolicy? Callback to be called on emit.
---
---@return glacier.signal.SignalHandle
function signal.connect(name, callback)
    return global_emitter:connect(name, callback)
end

--- Send a signal to every registered handlers
---
--- @param name string Signal to emit
--- @param ... any Parameter to send to the callbacks
function signal.emit(name, ...)
    global_emitter:emit(name, ...)
end

--- Disconnect the callback managed by a handle
---
--- @param handle glacier.signal.SignalHandle
function signal.disconnect(handle)
    handle:disconnect()
end

return signal
