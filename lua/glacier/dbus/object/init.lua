local _errors = require("glacier.dbus.errors")
local _fdo = require("glacier.dbus.object.freedesktop")
local _interface = require("glacier.dbus.object.interface")
local _internals = require("glacier.dbus.object.internals")
local _method = require("glacier.dbus.object.method")
local _signal_emitter = require("glacier.dbus.object.signal_emitter")
local _types = require("glacier.dbus.type")

local _introspection_intf = "org.freedesktop.DBus.Introspectable"
local _introspection_member = "Introspect"
local _introspection_header = [[
<!DOCTYPE node PUBLIC   "-//freedesktop//DTD D-BUS Object Introspection 1.0//EN"
                        "http://www.freedesktop.org/standards/dbus/1.0/introspect.dtd">

]]

---@class glacier.dbus.object.WeakMethodContext
---@field _connection glacier.dbus.Connection
---@field _router glacier.dbus.ObjectRouter
---@field _interface glacier.dbus.object.Interface
local WeakMethodContext = {}
WeakMethodContext.__index = WeakMethodContext
WeakMethodContext.__name = "dbus.object.WeakMethodContext"
WeakMethodContext.__mode = "kv"

---@param connection glacier.dbus.Connection
---@param router glacier.dbus.ObjectRouter
---@param interface glacier.dbus.object.Interface
---
---@return glacier.dbus.object.WeakMethodContext
local function WeakMethodContext_new(connection, router, interface)
    return setmetatable({
        _connection = connection,
        _router = router,
        _interface = interface,
    }, WeakMethodContext)
end

---@return glacier.dbus.Connection?
---@return string?
function WeakMethodContext:connection()
    if self._connection then
        return self._connection
    else
        return nil, _errors.Expired
    end
end

---@return glacier.dbus.ObjectRouter?
---@return string?
function WeakMethodContext:router()
    if self._router then
        return self._router
    else
        return nil, _errors.Expired
    end
end

---@return glacier.dbus.object.Interface?
---@return string?
function WeakMethodContext:interface()
    if self._interface then
        return self._interface
    else
        return nil, _errors.Expired
    end
end

---@class glacier.dbus.object.MethodContext
---@field _weak glacier.dbus.object.WeakMethodContext
---@field _path glacier.dbus.type.ObjectPath
---@field _emitter glacier.dbus.object.SignalEmitter
local MethodContext = {}
MethodContext.__index = MethodContext
MethodContext.__name = "dbus.object.MethodContext"

---@param connection glacier.dbus.Connection
---@param router glacier.dbus.ObjectRouter
---@param interface glacier.dbus.object.Interface
---@param path glacier.dbus.type.ObjectPath
local function MethodContext_new(connection, router, path, interface)
    return setmetatable({
        _weak = WeakMethodContext_new(connection, router, interface),
        _path = _types.object_path.from_str(path:get()),
        _emitter = _signal_emitter.new(connection, path),
    }, MethodContext)
end

function MethodContext:connection()
    return self._weak:connection()
end

function MethodContext:router()
    return self._weak:router()
end

function MethodContext:interface()
    return self._weak:interface()
end

function MethodContext:path()
    return self._path
end

function MethodContext:emitter()
    return self._emitter
end

---@class glacier.dbus.Object
---@field _interfaces table<string, glacier.dbus.object.Interface>
local Object = {}
Object.__index = Object
Object.__name = "glacier.dbus.Object"

function Object.new()
    local ret = setmetatable({
        _interfaces = {},
    }, Object)

    return ret:add_interface(_fdo.Properties)
end

function Object:add_interface(interface)
    if not _types.is(interface, _interface.Interface) then
        return nil, _errors.type.Invalid
    end

    local name = interface:name_str()
    self._interfaces[name] = interface

    return self
end

---@param name string
---@return glacier.dbus.object.Interface?
function Object:interface(name)
    return self._interfaces[name]
end

function Object:introspect()
    local iface = {}

    for _, intf in pairs(self._interfaces) do
        table.insert(iface, intf:introspect())
    end

    return table.concat(iface, "\n")
end

---@class glacier.dbus.ObjectRouter
---@field _weak_connection glacier.dbus.WeakConnection
---@field _objects table<string, glacier.dbus.Object>
local ObjectRouter = {}
ObjectRouter.__index = ObjectRouter
ObjectRouter.__name = "glacier.dbus.ObjectRouter"

---@param weak glacier.dbus.WeakConnection
local function ObjectRouter_new(weak)
    return setmetatable({
        _weak_connection = weak,
        _objects = {},
    }, ObjectRouter)
end

---@param path string|glacier.dbus.type.ObjectPath
---@param object glacier.dbus.Object
function ObjectRouter:object_at(path, object)
    local path_str, err = _internals.check_path(path)
    if not path_str then
        return nil, err
    end

    if not _types.is(object, Object) then
        return nil, _errors.type.Invalid
    end

    self._objects[path_str] = object
    return self
end

---@param path string|glacier.dbus.type.ObjectPath
---
---@return glacier.dbus.object.SignalEmitter?
---@return string?
function ObjectRouter:emitter_for(path)
    local c = self._weak_connection:upgrade()
    if not c then
        return nil, _errors.Expired
    end

    local path_str, err = _internals.check_path(path)
    if not path_str then
        return nil, err
    end

    if not self._objects[path_str] then
        return nil, _errors.ObjectNotFound
    end

    return _signal_emitter.new(c, path)
end

---@param path string|glacier.dbus.type.ObjectPath
---@param interface glacier.dbus.object.Interface
function ObjectRouter:interface_at(path, interface)
    local path_str, err = _internals.check_path(path)
    if not path_str then
        return nil, err
    end

    self._objects[path_str] = self._objects[path_str] or Object.new()

    local ok
    ok, err = self._objects[path_str]:add_interface(interface)

    if not ok then
        return nil, err
    end

    return self
end

---@param path string|glacier.dbus.type.ObjectPath
---@param interface string|glacier.dbus.type.InterfaceName
---
---@return glacier.dbus.object.Interface?
---@return string?
function ObjectRouter:get_interface(path, interface)
    local path_str, err = _internals.check_path(path)
    if not path_str then
        return nil, err
    end

    ---@diagnostic disable-next-line:cast-local-type
    interface, err = _types.interface_name.try_from(interface)
    if not interface then
        return nil, err
    end

    local obj = self._objects[path_str]
    if not obj then
        return nil, _errors.ObjectNotFound
    end

    local iface = obj:interface(interface:str())
    if not iface then
        return nil, _errors.InterfaceNotFound
    end

    return iface
end

---@param message glacier.dbus.Message
---@return glacier.dbus.Message
function ObjectRouter:_introspect(message)
    local path = message:path():get()

    local pattern = path == "/" and "^/" or "^" .. path .. "/"
    local objects = {}

    for k, o in pairs(self._objects) do
        local rem, match = string.gsub(k, pattern, "")

        if path == k then
            table.insert(objects, o:introspect())
            --TODO: Proper object introspection.
        elseif match then
            table.insert(objects, ("  <node name=%q/>"):format(rem))
        end
    end

    local content = ([[
<node>
%s
</node>
    ]]):format(table.concat(objects, "\n"))

    local str = _introspection_header .. content

    return message:method_return(_types.Struct({
        _types.String(str),
    }))
end

---@param connection glacier.dbus.Connection
---@param message glacier.dbus.Message
---
---@return glacier.dbus.Message # Message response, if the message was dispatched
function ObjectRouter:dispatch(connection, message)
    assert(message:type() == _types.message_type.MethodCall, "Expected MethodCall")

    if
        message:interface():str() == _introspection_intf
        and message:member():str() == _introspection_member
    then
        return self:_introspect(message)
    end

    local path = message:path() --[[@as glacier.dbus.type.ObjectPath]]
    ---@type string
    local path_str = path:get()
    local object = self._objects[path_str]
    if not object then
        return message:reply_error(_errors.dbus.UnknownObject, path_str)
    end

    local name = message:interface():str()
    local interface = object:interface(name)

    if not interface then
        return message:reply_error(_errors.dbus.UnknownInterface, name)
    end

    local ctx = MethodContext_new(connection, self, path, interface)

    return interface:call(ctx, message)
end

---@class glacier.dbus.object
local object = {
    Object = Object,
    Interface = _interface.Interface,
    Method = _method.Method,

    interface = _interface,
    method = _method,
}

---@param weak glacier.dbus.WeakConnection
---
---@return glacier.dbus.ObjectRouter
function object.router(weak)
    return ObjectRouter_new(weak)
end

return object
