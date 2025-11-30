local _errors = require("glacier.dbus.errors")
local _member_name = require("glacier.dbus.type.member_name")
local _strong_type = require("glacier.dbus.type.strong_type")

---@enum glacier.dbus.object.property.SignalPolicy
local SignalPolicy = {
    True = "true",
    Invalidates = "invalidates",
    Const = "const",
    False = "false",
    Inherit = "",
}

local _valid_policy = {
    ["true"] = 1,
    ["invalidates"] = 1,
    ["const"] = 1,
    ["false"] = 1,
    [""] = 1,
}

---@class glacier.dbus.object.Property
---@field _name glacier.dbus.type.MemberName
---@field _value glacier.dbus.type.StrongType
---@field _read boolean
---@field _write boolean
---@field _signal_policy glacier.dbus.object.property.SignalPolicy
local Property = {}
Property.__index = Property
Property.__name = "dbus.object.Property"

---@param name glacier.dbus.type.MemberName
---@param value glacier.dbus.type.StrongType
---@param read boolean
---@param write boolean
---@param policy glacier.dbus.object.property.SignalPolicy
---
---@return glacier.dbus.object.Property
local function Property_new(name, value, read, write, policy)
    return setmetatable({
        _name = name,
        _value = value,
        _read = read,
        _write = write,
        _signal_policy = policy,
    }, Property)
end

---Gets the `Property` name.
function Property:name()
    return self._name
end

---Get the `Property` value
function Property:get()
    return self._value -- TODO: CLONE
end

---Sets the `Property` value.
---@param value glacier.dbus.type.StrongType
---
---@return glacier.dbus.object.Property?
---@return string?
function Property:set(value)
    if not _strong_type.is_strong_type(value) then
        return nil, _errors.type.Invalid
    elseif self._value:signature() ~= value:signature() then
        return nil, _errors.type.Invalid
    elseif not _strong_type.is_strong_value(value) then
        return nil, _errors.type.ExpectedValue
    end

    if self._signal_policy == SignalPolicy.Const then
        return nil, _errors.dbus.PropertyReadOnly
    end

    self._value = value
    return self
end

---Whether the `Property` can be read from the bus.
---
---@return boolean
function Property:is_read()
    return self._read
end

---Whether the Property can be written to from the bus.
---
---@return boolean
function Property:is_write()
    return self._write or self._signal_policy == SignalPolicy.Const
end

---Returns the `Property` signal policy.
---
---@return glacier.dbus.object.property.SignalPolicy
function Property:policy()
    return self._signal_policy
end

---@return string
function Property:introspect()
    local property_prefix = "      "
    local annotation_prefix = property_prefix .. "  "
    local anno_name = "org.freedesktop.DBus.EmitsChangedSignal"

    local name = self._name:str()
    local type = self._value:signature():compute_str(1)
    local access = self._read and "read" or ""
    access = access .. (self:is_write() and "write" or "")

    local str
    if self._signal_policy == SignalPolicy.Inherit then
        str = property_prefix
            .. ("<property name=%q type=%q access=%q/>"):format(name, type, access)
    else
        str = property_prefix
            .. ("<property name=%q type=%q access=%q>\n"):format(name, type, access)
        str = str
            .. annotation_prefix
            .. ("<annotation name=%q value=%q/>\n"):format(anno_name, self._signal_policy)
        str = str .. property_prefix .. "</property>"
    end

    return str
end

---@class glacier.dbus.object.property.Builder
---@field name glacier.dbus.type.MemberName
---@field read boolean
---@field write boolean
---@field policy glacier.dbus.object.property.SignalPolicy
local Builder = {}
Builder.__index = Builder
Builder.__name = "dbus.object.property.Builder"

local function Builder_new()
    return setmetatable({
        read = true,
        write = true,
        policy = SignalPolicy.Inherit,
    }, Builder)
end

---@param name string|glacier.dbus.type.MemberName
---
---@return glacier.dbus.object.property.Builder?
---@return string?
function Builder:with_name(name)
    local err
    ---@diagnostic disable-next-line:cast-local-type
    name, err = _member_name.try_from(name)
    if not name then
        return nil, err
    end

    self.name = name
    return self
end

---@param v? boolean # If nil, make the property readable. Otherwise, set the flag.
---@return glacier.dbus.object.property.Builder?
---@return string?
function Builder:readable(v)
    self.read = v == nil or v == true
end

---@param v? boolean # If nil, make the property writeable. Otherwise, sets the flag.
---
---@return glacier.dbus.object.property.Builder?
---@return string?
function Builder:writeable(v)
    self.write = v == nil or v == true
end

---@param policy glacier.dbus.object.property.SignalPolicy
---@return glacier.dbus.object.property.Builder?
---@return string?
function Builder:with_policy(policy)
    if not _valid_policy[policy] then
        return nil, _errors.type.Invalid
    end

    self.policy = policy
    return self
end

---@param value glacier.dbus.type.StrongType
---
---@return glacier.dbus.object.Property?
---@return string?
function Builder:build(value)
    if not _strong_type.is_strong_value(value) then
        return nil, _errors.type.ExpectedValue
    end

    return Property_new(self.name, value, self.read, self.write, self.policy), nil
end

---@class glacier.dbus.object.property
local property = {
    Property = Property,
    SignalPolicy = SignalPolicy,
}

---@param name string|glacier.dbus.type.MemberName
---
---@return glacier.dbus.object.property.Builder?
---@return string?
function property.builder(name)
    local ret = Builder_new()

    return ret:with_name(name)
end

return property
