local cqueues = require("cqueues")

---@class glacier.dbus.connection.Timeout
---@field inner ldbus.DBusTimeout
---@field interval number Timeout interval, in seconds.
---@field next_tick number Time at which the timeout handler should be called.
local Timeout = {}
Timeout.__index = Timeout
Timeout.__name = "dbus.connection.Timeout"

---Wrap a `ldbus.DBusTimeout` into a pollable `glacier.dbus.Timeout`.
---
---This object implement cqueues polling convention.
---
---@param timeout ldbus.DBusTimeout
---@return glacier.dbus.connection.Timeout
local function Timeout_new(timeout)
    local ret = {
        inner = timeout,
        interval = timeout:get_interval(),
    }

    setmetatable(ret, Timeout)

    ret:reset_interval()
    return ret
end

---Reset this timer interval.
---
---This should be called when the enabled status changed.
---
---@private
function Timeout:reset_interval()
    local interval = self.inner:get_interval()
    -- get_interval return number in millisec, we want it in seconds.
    self.interval = tonumber(interval) / 1000.
    self:get_next_tick()
end

---Function to call when the underlying DBusTimeout is toggled.
function Timeout:enable_changed()
    self:reset_interval()
    self.enabled = self.inner:get_enabled()
end

---Call the Timeout handler.
---
---@return boolean # Return `false` if there wasn't enough memory.
function Timeout:handle()
    local ret = self.inner:handle()

    self.next_tick = self:get_next_tick()
    return ret
end

---Return the next tick time.
---
---@private
---@return number
function Timeout:get_next_tick()
    local now = cqueues.monotime()
    return now + self.interval()
end

---@return string
function Timeout:type()
    return "Timeout"
end

---@return nil
function Timeout:pollfd()
    return nil
end

---@return nil
function Timeout:events()
    return nil
end

---Return the time in second until the next tick.
---
---@return number # Amount of time to wait until this timeout expires.
function Timeout:timeout()
    local now = cqueues.monotime()

    if now >= self.next_tick then
        return 0.
    else
        return self.next_tick - now
    end
end

---@class glacier.dbus.connection.timeout
local timeout = {
    Timeout = Timeout,
}

---Create a new `Timeout`.
---
---@param timeout ldbus.DBusTimeout
---@return glacier.dbus.connection.Timeout
function timeout.from_ldbus(timeout) ---@diagnostic disable-line:redefined-local
    return Timeout_new(timeout)
end

return timeout
