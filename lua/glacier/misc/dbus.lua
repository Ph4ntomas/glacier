local Log = require("snowcap.log")

local Connection = require("glacier.dbus.connection")
local event_loop = require("glacier.internals.event_loop")

---@type glacier.dbus.Connection
local _session_bus

---@type glacier.dbus.Connection
local _system_bus

---@class glacier.misc.dbus
local dbus = {}

---@param connection? glacier.dbus.Connection
---
---@return glacier.dbus.Connection
function dbus.init_session(connection)
    if _session_bus then
        Log.error("Session bus already exists.")
    end

    if connection then
        _session_bus = connection
    else
        local builder = Connection.session()
        local new_bus, err = builder:build()
        if not new_bus then
            Log.error("Could not create a session bus: " .. tostring(err))
            error("Could not create a session bus: " .. tostring(err))
        end

        _session_bus = new_bus
    end

    event_loop.loop:wrap(function()
        while not _session_bus:stopping() do
            _session_bus:step()
        end

        ---@diagnostic disable-next-line:cast-local-type
        _session_bus = nil
    end)

    return _session_bus
end

---@param connection? glacier.dbus.Connection
---
---@return glacier.dbus.Connection
function dbus.init_system(connection)
    if _system_bus then
        Log.error("System bus already exists.")
    end

    if connection then
        _system_bus = connection
    else
        local builder = Connection.system()
        local new_bus, err = builder:build()
        if not new_bus then
            Log.error("Could not create a system bus: " .. tostring(err))
            error("Could not create a system bus: " .. tostring(err))
        end

        _system_bus = new_bus
    end

    event_loop.loop:wrap(function()
        while not _system_bus:stopping() do
            _system_bus:step()
        end

        ---@diagnostic disable-next-line:cast-local-type
        _system_bus = nil
    end)

    return _system_bus
end

---@return glacier.dbus.Connection
function dbus.session()
    if not _session_bus then
        dbus.init_session()
    end

    return _session_bus
end

---@return glacier.dbus.Connection
function dbus.system()
    if not _system_bus then
        return dbus.init_system()
    end

    return _system_bus
end

return dbus
