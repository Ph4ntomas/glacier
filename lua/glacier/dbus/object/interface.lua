local _errors = require("glacier.dbus.errors")
local _types = require("glacier.dbus.type")
local _method = require("glacier.dbus.object.method")
local _signal = require("glacier.dbus.object.signal")
local _signal_emitter = require("glacier.dbus.object.signal_emitter")
local _property = require("glacier.dbus.object.property")

local _props_interface = "org.freedesktop.DBus.Properties"
local _props_signal = "PropertiesChanged"

---@class glacier.dbus.object.Interface
---@field _name glacier.dbus.type.InterfaceName
---@field _methods table<string, glacier.dbus.object.Method>
---@field _signals table<string, glacier.dbus.object.Signal>
---@field _properties table<string, glacier.dbus.object.Property>
local Interface = {}
Interface.__index = Interface
Interface.__name = "dbus.object.Interface"

---@param iface glacier.dbus.object.Interface
---@return glacier.dbus.object.Interface
local function Interface_new(iface)
    return setmetatable(iface, Interface)
end

---@return glacier.dbus.type.InterfaceName
function Interface:name()
    return self._name
end

---@return string
function Interface:name_str()
    return self._name:str()
end

---@param context glacier.dbus.object.MethodContext
---@param message glacier.dbus.Message
---@return glacier.dbus.Message
function Interface:call(context, message)
    local name = message:member():str()
    local method = self._methods[name]

    if not method then
        return message:reply_error(_errors.dbus.UnknownMethod, name)
    end

    return method:call(context, message)
end

---@param emitter glacier.dbus.object.SignalEmitter
---@param member string|glacier.dbus.type.MemberName
---@param body? glacier.dbus.type.Struct
function Interface:emit(emitter, member, body)
    return self:emit_to(emitter, nil, member, body)
end

---@param emitter glacier.dbus.object.SignalEmitter
---@param destination? glacier.dbus.type.ToBusName
---@param member string|glacier.dbus.type.MemberName
---@param body? glacier.dbus.type.Struct
function Interface:emit_to(emitter, destination, member, body)
    local err
    ---@diagnostic disable-next-line:cast-local-type
    member, err = _types.member_name.try_from(member)
    if not member then
        return nil, err
    end

    local name = member:str()
    local signal = self._signals and self._signals[name]
    if not signal then
        return nil, _errors.UnknownSignal
    end

    if not signal:check_body() then
        return nil, _errors.type.Invalid
    end

    return emitter:emit_to(destination, self._name, member, body)
end

---@param name string|glacier.dbus.type.MemberName
---
---@return glacier.dbus.object.Property?
---@return string?
function Interface:property(name)
    local pname
    if type(name) == "string" then
        pname = name
    elseif _types.is(name, _types.MemberName) then
        pname = name:str()
    else
        return nil, _errors.type.Invalid
    end

    local prop = self._properties[pname]
    if not prop then
        return nil, _errors.dbus.UnknownProperty
    end

    return prop
end

---@param name string|glacier.dbus.type.MemberName
---
---@return glacier.dbus.type.StrongType?
---@return string?
function Interface:get(name)
    local prop, err = self:property(name)
    if not prop then
        return nil, err
    end

    return prop:get()
end

---@return table<string, glacier.dbus.type.StrongType>
function Interface:get_all()
    local props = {}

    for k, v in pairs(self._properties) do
        if v:is_read() then
            props[k] = v:get()
        end
    end

    return props
end

---@private
---@param emitter glacier.dbus.object.SignalEmitter
---@param prop glacier.dbus.object.Property
---
---@return glacier.dbus.object.Interface?
---@return string?
function Interface:_emit_property_changed(emitter, prop)
    local policy = prop:policy()
    if policy == _property.SignalPolicy.Inherit then
        policy = _property.SignalPolicy.True
    end

    if policy == _property.SignalPolicy.Const or policy == _property.SignalPolicy.False then
        return self
    end

    local c, err = emitter:connection()
    if not c then
        return nil, err
    end

    local prop_iface = c:router():get_interface(emitter:path(), _props_interface) --[[@as glacier.dbus.object.Interface]]

    local changed = _types.Dict(_types.String, _types.Variant)
    local invalidated = _types.Array(_types.String)

    if policy == _property.SignalPolicy.True then
        changed[prop:name():str()] = _types.Variant(prop:get())
    elseif policy == _property.SignalPolicy.Invalidates then
        table.insert(invalidated, prop:name():str())
    end

    local body = _types.Struct({
        _types.String(self:name_str()),
        changed,
        invalidated,
    })

    prop_iface:emit(emitter, _props_signal, body)

    return self
end

---@param emitter glacier.dbus.object.SignalEmitter
---@param name string|glacier.dbus.type.MemberName
---@param value glacier.dbus.type.StrongType
---
---@return glacier.dbus.object.Interface?
---@return string?
function Interface:set(emitter, name, value)
    if not _types.is(emitter, _signal_emitter.SignalEmitter) then
        return nil, _errors.type.Invalid
    end

    local prop, err = self:property(name)
    if not prop then
        return nil, err
    end

    local ok
    ok, err = prop:set(value)
    if not ok then
        return nil, err
    end

    return self:_emit_property_changed(emitter, prop)
end

---@return string
function Interface:introspect()
    local iface_prefix = "    "
    local open_str = ("<interface name=%q>\n"):format(self:name_str())
    local close_str = "</interface>"

    local methods = {}
    for _, v in pairs(self._methods) do
        table.insert(methods, v:introspect())
    end

    local signals = {}
    for _, v in pairs(self._signals) do
        table.insert(signals, v:introspect())
    end

    local properties = {}
    for _, v in pairs(self._properties) do
        table.insert(properties, v:introspect())
    end

    local ret = iface_prefix .. open_str

    if #methods > 0 then
        ret = ret .. table.concat(methods, "\n") .. "\n"
    end

    if #signals > 0 then
        ret = ret .. table.concat(signals, "\n") .. "\n"
    end

    if #properties > 0 then
        ret = ret .. table.concat(properties, "\n") .. "\n"
    end

    ret = ret .. iface_prefix .. close_str
    return ret
end

---@class glacier.dbus.object.interface.Builder
---@field name glacier.dbus.type.InterfaceName
---@field methods table<string, glacier.dbus.object.Method>
---@field signals table<string, glacier.dbus.object.Signal>
---@field properties table<string, glacier.dbus.object.Property>
local Builder = {}
Builder.__index = Builder
Builder.__name = "dbus.object.interface.Builder"

---@param name glacier.dbus.type.InterfaceName
---@return glacier.dbus.object.interface.Builder?
local function Builder_new(name)
    return setmetatable({
        name = name,
        methods = {},
        signals = {},
        properties = {},
    }, Builder)
end

---@param method glacier.dbus.object.Method
function Builder:with_method(method)
    if not _types.is(method, _method.Method) then
        return nil, _errors.type.Invalid
    end

    local name = method:name():str()
    self.methods[name] = method

    return self
end

---@param signal glacier.dbus.object.Signal
function Builder:with_signal(signal)
    if not _types.is(signal, _signal.Signal) then
        return nil, _errors.type.Invalid
    end

    local name = signal:name():str()
    self.signals[name] = signal

    return self
end

---@param property glacier.dbus.object.Property
function Builder:with_property(property)
    if not _types.is(property, _property.Property) then
        return nil, _errors.type.Invalid
    end

    local name = property:name():str()
    self.properties[name] = property

    return self
end

---@return glacier.dbus.object.Interface
function Builder:build()
    return Interface_new({
        _name = self.name,
        _methods = self.methods,
        _signals = self.signals,
        _properties = self.properties,
    })
end

local interface = {
    Interface = Interface,
}

---@param name string|glacier.dbus.type.InterfaceName
---@return glacier.dbus.object.interface.Builder?
---@return string?
function interface.builder(name)
    if type(name) == "string" then
        local err
        ---@diagnostic disable-next-line:cast-local-type
        name, err = _types.interface_name.try_from_str(name)
        if not name then
            return nil, err
        end
    elseif not _types.is(name, _types.InterfaceName) then
        return nil, _errors.type.Invalid
    end

    ---@cast name glacier.dbus.type.InterfaceName
    return Builder_new(name), nil
end

return interface
