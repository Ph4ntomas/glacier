local promise = require("cqueues.promise") --[[@as cqueues.promiselib]]

local _call_res = require("glacier.dbus.message.call_result")
local _messages = require("glacier.dbus.message")

---@enum glacier.dbus.connection.PendingStatus
local PendingStatus = {
    pending = "pending",
    fulfilled = "fullfilled",
    rejected = "rejected",
}

---@class glacier.dbus.connection.PendingCall
---@field package inner ldbus.DBusPendingCall
---@field package _promise cqueues.promise
local PendingCall = {}
PendingCall.__index = PendingCall
PendingCall.__name = "dbus.connection.PendingCall"

---@param pending glacier.dbus.connection.PendingCall
local function PendingCall_notify(pending)
    local message = pending.inner:steal_reply()

    if not message then
        pending._promise:set(false, "got nil")
    else
        pending._promise:set(pcall(function()
            return _messages.from_ldbus(message)
        end))
    end
end

---@param inner ldbus.DBusPendingCall
---@return glacier.dbus.connection.PendingCall
local function PendingCall_new(inner)
    local ret = setmetatable({
        inner = inner,
        _promise = promise.new(),
    }, PendingCall)

    inner:set_notify(function()
        PendingCall_notify(ret)
    end)

    return ret
end

---Gets the response `Message` unprocessed.
---
---If `timeout` is set, this function fill wait up to the specified amount of time, and return nil
---if no answer was received.
---
---@param timeout? number
---
---@return glacier.dbus.Message? # On timeout, returns nil.
function PendingCall:get_raw(timeout)
    return self._promise:get(timeout)
end

---Gets the response `Message`, turning it into a `CallResult`.
---
---If `timeout` is set, this function fill wait up to the specified amount of time, and return nil
---if no answer was received.
---
---@param timeout number
---
---@return glacier.dbus.message.CallResult? # On timeout, returns nil.
---@overload fun(): glacier.dbus.message.CallResult
function PendingCall:get(timeout)
    local msg = self:get_raw(timeout)

    if msg == nil then
        return nil
    end

    return _call_res.from_message(msg)
end

---Wait for a `Message` to be received.
---@param timeout? number
---
---@return glacier.dbus.connection.PendingCall?
function PendingCall:wait(timeout)
    if self._promise:wait(timeout) then
        return self
    end
    return nil
end

---Return the status of the PendingCall internal promise.
---@return glacier.dbus.connection.PendingStatus
function PendingCall:status()
    return PendingStatus[self._promise:status()]
end

---@return cqueues.promise
function PendingCall:promise()
    return self._promise
end

---@class glacier.dbus.connection.pending_call
local pending_call = {
    PendingCall = PendingCall,
    PendingStatus = PendingStatus,
}

---@param pending ldbus.DBusPendingCall
---@return glacier.dbus.connection.PendingCall
function pending_call.from_ldbus(pending)
    return PendingCall_new(pending)
end

return pending_call
