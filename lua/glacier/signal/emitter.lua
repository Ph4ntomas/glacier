local Log = require("pinnacle.log")

---`glacier.signal.emitter` module.
---
---This is an internal moduel. See `glacier.signal` for the actual documentation.
---
---@class glacier.signal.emitter
local emitter = {}

---@enum glacier.signal.HandlerPolicy
---| 'Keep' # Keep the handler
---| 'Discard' # Discard the handler.
emitter.HandlerPolicy = {
    ---Keep the handler
    Keep = false,
    ---Discard the handler
    Discard = true,
}

---Store a callback.
---@class glacier.signal.SignalCallback
---@field id integer
---@field callback fun(...): glacier.signal.HandlerPolicy?

---Handle to a signal callback.
---@class glacier.signal.SignalHandle
---@field private callback? glacier.signal.SignalCallback
---@field private entry? glacier.signal.SignalEntry
local SignalHandle = {}

---Disconnect the callback managed by this handle
function SignalHandle:disconnect()
    if self.entry and self.callback then
        self.entry:remove_callback(self.callback)
    end
end

---Convert a `SignalHandle` into a printable string
---
---@param handle glacier.signal.SignalHandle
---
---@return string
function SignalHandle.tostring(handle)
    if handle.entry then
        return "SignalHandle{" .. handle.entry.signal .. "#" .. tostring(handle.callback.id) .. "}"
    else
        return "SignalHandle{StaleHandle}"
    end
end

---@private
---@class glacier.signal.SignalEntry
---@field id integer
---@field signal string Name of the signal in this entry
---@field signals glacier.signal.SignalCallback[]
local SignalEntry = {}

---Create a new SignalEntry
---
---@private
---@param signal string Signal name.
---@nodiscard
---@return glacier.signal.SignalEntry
function SignalEntry.new(signal)
    local entry = {
        id = 0,
        signal = signal,
        signals = {},
    }

    setmetatable(entry, { __index = SignalEntry })
    return entry
end

---Get a valid id for a callback
---
---@private
---@nodiscard
---@return integer
function SignalEntry:next_id()
    local newid = self.id
    self.id = self.id + 1

    return newid
end

---Add a new callback for this entry.
---
---@param callback fun(...)
---@nodiscard
---@return glacier.signal.SignalHandle
function SignalEntry:add_callback(callback)
    ---@type glacier.signal.SignalCallback
    local signal = {
        id = self:next_id(),
        callback = callback,
    }

    table.insert(self.signals, signal)

    local handle = setmetatable({
        entry = self,
        callback = signal,
    }, { __index = SignalHandle, __tostring = SignalHandle.tostring, __mode = "kv" })

    return handle
end

---Remove a callback from this entry.
---
---@param signal_cb glacier.signal.SignalCallback
function SignalEntry:remove_callback(signal_cb)
    local idx = nil

    for k, callback in pairs(self.signals) do
        if callback == signal_cb then
            idx = k
            break
        end
    end

    if idx ~= nil then
        table.remove(self.signals, idx)
    end
end

---Emit the message corresponding to this entry.
---
---@param ... any Parameters to pass to the callbacks
function SignalEntry:emit(...)
    local to_remove = {}

    for _, callback in pairs(self.signals) do
        local ok, ret = pcall(callback.callback, ...)

        if ok and ret == emitter.HandlerPolicy.Discard then
            to_remove = callback
        elseif not ok then
            Log.error("While handling '" .. self.signal .. "': " .. ret)
        end
    end

    for _, callback in pairs(to_remove) do
        self:remove_callback(callback)
    end
end

---Remove all callbacks from this entry.
function SignalEntry:clear()
    self.signals = {}
end

---Signal emitter.
---
---@class glacier.signal.Emitter
---@field private entries table<string, glacier.signal.SignalEntry>
local Emitter = {}

---Get the `SignalEntry` associated with a signal, or return a new entry.
---
---@private
---@param signal string Signal we want the entry to
---@nodiscard
---@return glacier.signal.SignalEntry
function Emitter:get_or_default(signal)
    self.entries[signal] = self.entries[signal] or SignalEntry.new(signal)

    return self.entries[signal]
end

---Get the `SignalEntry` associated with a signal
---
---@private
---@param name string Signal we want the entry to
---@return glacier.signal.SignalEntry?
function Emitter:get(name)
    return self.entries[name]
end

---Emit a signal
---@param name string Signal to emit
---@param ... any Signal callback parameters
function Emitter:emit(name, ...)
    local entry = self:get(name)

    if not entry then
        return
    end

    entry:emit(...)
end

---Connect a callback to a specific signal
---
---@param name string Signal to connect to
---@param callback fun(...): boolean? Callback to register
---@return glacier.signal.SignalHandle
function Emitter:connect(name, callback)
    local entry = self:get_or_default(name)

    return entry:add_callback(callback)
end

---Disconnect a callback managed by a handle
---@param handle glacier.signal.SignalHandle Handle to the signal we want to disconnect
function Emitter:disconnect(handle)
    ---@diagnostic disable: invisible
    if handle.entry then
        local entry = self:get(handle.entry.signal)

        if entry then
            entry:remove_callback(handle.callback)
        else
            Log.error(tostring(handle)(" wasn't meant for this Emitter"))
        end
    end
end

---Disconnect all callbacks from this table.
function Emitter:disconnect_all()
    for _, entry in pairs(self.entries) do
        entry:clear()
    end

    self.entries = {}
end

---Construct a new Emitter
---
---@param o? any
---@return glacier.signal.Emitter
function Emitter:new(o)
    o = o or {}

    o.entries = {}

    setmetatable(o, self)
    self.__index = self
    return o
end

emitter.Emitter = Emitter

return emitter
