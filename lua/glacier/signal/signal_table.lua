local Log = require("pinnacle.log")

---Store a callback.
---@class glacier.signal.SignalCallback
---@field id integer
---@field callback fun(...): boolean?

---Handle to a signal callback.
---@class glacier.signal.SignalHandle
---@field private callback? glacier.signal.SignalCallback
---@field private entry? glacier.signal.SignalEntry
local SignalHandle = {}

--- Disconnect the callback managed by this handle
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

        if ok and ret == true then
            to_remove = callback
        elseif not ok then
            Log.error("While handling '" .. self.signal .. "': " .. ret)
        end
    end

    for _, callback in pairs(to_remove) do
        self:remove_callback(callback)
    end
end

---Remove all callbacks from this entry
function SignalEntry:flush()
    self.signals = {}
end

---Signal Table.
---
---@class glacier.signal.SignalTable
---@field entries table<string, glacier.signal.SignalEntry>
local SignalTable = {}

---Get the `SignalEntry` associated with a signal, or return a new entry.
---
---@private
---@param signal string Signal we want the entry to
---@nodiscard
---@return glacier.signal.SignalEntry
function SignalTable:get_or_default(signal)
    self.entries[signal] = self.entries[signal] or SignalEntry.new(signal)

    return self.entries[signal]
end

---Get the `SignalEntry` associated with a signal
---
---@private
---@param name string Signal we want the entry to
---@return glacier.signal.SignalEntry?
function SignalTable:get(name)
    return self.entries[name]
end

---Emit a signal
---@param name string Signal to emit
---@param ... any Signal callback parameters
function SignalTable:emit(name, ...)
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
function SignalTable:connect(name, callback)
    local entry = self:get_or_default(name)

    return entry:add_callback(callback)
end

---Disconnect a callback managed by a handle
---@param handle glacier.signal.SignalHandle Handle to the signal we want to disconnect
function SignalTable:disconnect(handle)
    ---@diagnostic disable: invisible
    if handle.entry then
        local entry = self:get(handle.entry.signal)

        if entry then
            entry:remove_callback(handle.callback)
        else
            Log.error(tostring(handle)(" wasn't meant for this SignalTable"))
        end
    end
end

---Disconnect all callbacks from this table.
function SignalTable:disconnect_all()
    for _, entry in pairs(self.entries) do
        entry:flush()
    end

    self.entries = {}
end

--- Create a new SignalTable
---@return glacier.signal.SignalTable
local function signal_table()
    return setmetatable({
        entries = {},
    }, { __index = SignalTable })
end

return signal_table
