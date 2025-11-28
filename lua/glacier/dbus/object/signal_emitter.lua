local _errors = require("glacier.dbus.errors")
local _types = require("glacier.dbus.type")

---@class glacier.dbus.object.signal_emitter.Weak
---@field _connection glacier.dbus.Connection
local Weak = {}
Weak.__index = Weak
Weak.__name = "dbus.object.signal_emitter.Weak"
Weak.__mode = "kv"

---@param connection glacier.dbus.Connection
function Weak.new(connection)
    return setmetatable({
        _connection = connection,
    }, Weak)
end

---@class glacier.dbus.object.SignalEmitter
---@field _weak glacier.dbus.object.signal_emitter.Weak
---@field _path glacier.dbus.type.ObjectPath
local SignalEmitter = {}
SignalEmitter.__index = SignalEmitter
SignalEmitter.__name = "dbus.object.SignalEmitter"

---@param connection glacier.dbus.Connection
---@param path glacier.dbus.type.ObjectPath
---
---@return glacier.dbus.object.SignalEmitter
local function SignalEmitter_new(connection, path)
    return setmetatable({
        _weak = Weak.new(connection),
        _path = _types.object_path.from_str(path:get()),
    }, SignalEmitter)
end

---@return glacier.dbus.Connection?
---@return string?
function SignalEmitter:connection()
    if not self._weak._connection then
        return nil, _errors.Expired
    end

    return self._weak._connection
end

---@param interface string|glacier.dbus.type.InterfaceName
---@param name string|glacier.dbus.type.MemberName
---@param body? glacier.dbus.type.Struct
function SignalEmitter:emit(interface, name, body)
    return self:emit_to(nil, interface, name, body)
end

---@param destination? glacier.dbus.type.ToBusName
---@param interface string|glacier.dbus.type.InterfaceName
---@param name string|glacier.dbus.type.MemberName
---@param body? glacier.dbus.type.Struct
---
---@return glacier.dbus.object.SignalEmitter?
---@return string?
function SignalEmitter:emit_to(destination, interface, name, body)
    local connection = self._weak._connection
    if not connection then
        return nil, _errors.Expired
    end

    local err

    if destination then
        destination, err = _types.bus_name.try_from(destination)
        if not destination then
            return nil, err
        end
    end

    ---@diagnostic disable-next-line:cast-local-type
    interface, err = _types.interface_name.try_from(interface)
    if not interface then
        return nil, err
    end

    ---@diagnostic disable-next-line:cast-local-type
    name, err = _types.member_name.try_from(name)
    if not name then
        return nil, err
    end

    connection:emit_signal(destination, self._path, interface, name, body)
    return self
end

---@return glacier.dbus.type.ObjectPath
function SignalEmitter:path()
    return self._path
end

local signal_emitter = {
    SignalEmitter = SignalEmitter,
}

---@param connection glacier.dbus.Connection
---@param path string|glacier.dbus.type.ObjectPath
---
---@return glacier.dbus.object.SignalEmitter?
---@return string?
function signal_emitter.new(connection, path)
    if not connection then
        return nil
    end

    if type(path) == "string" then
        local err
        ---@diagnostic disable-next-line: cast-local-type
        path, err = _types.object_path.try_from_str(path)
        if not path then
            return nil, err
        end
    end

    return SignalEmitter_new(connection, path), nil
end

return signal_emitter
