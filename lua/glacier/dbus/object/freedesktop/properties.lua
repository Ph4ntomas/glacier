local _errors = require("glacier.dbus.errors")
local _interface = require("glacier.dbus.object.interface")
local _method = require("glacier.dbus.object.method")
local _signal = require("glacier.dbus.object.signal")
local _result = require("glacier.dbus.message.call_result")
local _types = require("glacier.dbus.type")

---@param ctx glacier.dbus.object.MethodContext
---@param interface_name glacier.dbus.type.String
---@param property_name glacier.dbus.type.String
---
---@return glacier.dbus.type.Variant|glacier.dbus.message.CallError
local function _get_property(ctx, interface_name, property_name)
    local router = assert(ctx:router())

    local iname = _types.interface_name.try_from(interface_name:get())
    if not iname then
        return _result.CallError.new(_errors.dbus.InvalidArgs, "interface_name")
    end
    local interface = router:get_interface(ctx:path(), iname)
    if not interface then
        return _result.CallError.new(_errors.dbus.UnknownInterface, iname:str())
    end

    local pname = property_name:get()
    local prop = interface:property(pname)
    if not prop then
        return _result.CallError.new(_errors.dbus.UnknownProperty, pname)
    end

    if prop:is_read() then
        return _types.Variant(prop:get())
    else
        return _result.CallError.new(_errors.dbus.UnknownProperty, pname)
    end
end

---@param ctx glacier.dbus.object.MethodContext
---@param interface_name glacier.dbus.type.String
---@param property_name glacier.dbus.type.String
---@param value glacier.dbus.type.Variant
---
---@return glacier.dbus.message.CallError?
local function _set_property(ctx, interface_name, property_name, value)
    local router = assert(ctx:router())
    local emitter = assert(ctx:emitter())

    local iname = _types.interface_name.try_from(interface_name:get())
    if not iname then
        return _result.CallError.new(_errors.dbus.InvalidArgs, "interface_name")
    end

    local interface = router:get_interface(ctx:path(), iname)
    if not interface then
        return _result.CallError.new(_errors.dbus.UnknownInterface, iname:str())
    end

    local pname = property_name:get()
    local prop = interface:property(pname)
    if not prop then
        return _result.CallError.new(_errors.dbus.UnknownProperty, pname)
    end

    if not prop:is_write() then
        return _result.CallError.new(_errors.dbus.PropertyReadOnly, pname)
    end

    local ok, err = interface:set(emitter, pname, value:get())
    if not ok then
        if err == _errors.type.Invalid then
            return _result.CallError.new(_errors.dbus.InvalidArgs, pname)
        else
            return _result.CallError.new(_errors.dbus.Failed, pname)
        end
    end
end

---@param ctx glacier.dbus.object.MethodContext
---@param interface_name glacier.dbus.type.String
---
---@return glacier.dbus.type.Dict|glacier.dbus.message.CallError
local function _get_all_properties(ctx, interface_name)
    local router = assert(ctx:router())

    local iname = _types.interface_name.try_from(interface_name:get())
    if not iname then
        return _result.CallError.new(_errors.dbus.InvalidArgs)
    end

    local interface, _ = router:get_interface(ctx:path(), iname)
    if not interface then
        return _result.CallError.new(_errors.dbus.UnknownInterface, iname:str())
    end

    local properties = interface:get_all()
    local props = {}

    for k, v in pairs(properties) do
        props[_types.String(k)] = _types.Variant(v)
    end

    return _types.Dict(props)
end

local methods = {}

methods.Get = assert(
    _method
        .builder("Get")
        :add_input("interface_name", _types.String)
        :add_input("property_name", _types.String)
        :add_output("value", _types.Variant)
        :with_handler(_get_property)
        :build()
)

methods.Set = assert(
    _method
        .builder("Set")
        :add_input("interface_name", _types.String)
        :add_input("property_name", _types.String)
        :add_input("value", _types.Variant)
        :with_handler(_set_property)
        :build()
)

methods.GetAll = assert(
    _method
        .builder("GetAll")
        :add_input("interface_name", _types.String)
        :add_output("props", _types.Dict(_types.String, _types.Variant))
        :with_handler(_get_all_properties)
        :build()
)

local PropertiesChanged = assert(
    _signal
        .builder("PropertiesChanged")
        :add_argument("interface_name", _types.String)
        :add_argument("changed_properties", _types.Dict(_types.String, _types.Variant))
        :add_argument("invalidated_properties", _types.Array(_types.String))
        :build()
)

local Properties = assert(
    _interface
        .builder("org.freedesktop.DBus.Properties")
        :with_method(methods.Get)
        :with_method(methods.Set)
        :with_method(methods.GetAll)
        :with_signal(PropertiesChanged)
        :build()
)

return Properties
