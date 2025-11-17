local errors = require("glacier.dbus.errors")
local _utils = require("glacier.dbus.type.utils")

---@class glacier.dbus.type.InterfaceName
---@field private repr string
local InterfaceName = {}
InterfaceName.__index = InterfaceName
InterfaceName.__name = "dbus.type.InterfaceName"

---@package
---Consructs a new `InterfaceName`.
---
---@param name string
---@return glacier.dbus.type.InterfaceName
local function InterfaceName_new(name)
    return setmetatable({ repr = name }, InterfaceName)
end

---Gets the `InterfaceName`, as a string.
---@return string
function InterfaceName:str()
    return self.repr
end

function InterfaceName:__tostring()
    return ("InterfaceName{%s}"):format(self.repr)
end

function InterfaceName.__eq(lhs, rhs)
    if lhs == nil and rhs == nil then
        return true
    elseif getmetatable(lhs) == InterfaceName and getmetatable(rhs) == InterfaceName then
        ---@cast lhs glacier.dbus.type.InterfaceName
        ---@cast rhs glacier.dbus.type.InterfaceName
        return lhs.repr == rhs.repr
    end

    return false
end

---@class glacier.dbus.type.interface_name
local interface_name = {}

---Checks if a string is a valid `InterfaceName`.
---@param name string
---@return boolean? # True if the string is valid
---@return string? # String decribing the error.
function interface_name.validate(name)
    if string.len(name) > 255 then
        return nil, errors.validation.NameTooLong
    end

    ---@diagnostic disable-next-line: redefined-local
    local name, matches = string.gsub(name, "^[%a_][%a%d_]*", "")

    if matches == 0 then
        return nil, errors.validation.InvalidInterfaceName
    end

    ---@diagnostic disable-next-line: redefined-local
    local name, matches = string.gsub(name, "%.[%a_][%a%d_]*", "")

    if matches == 0 or name ~= "" then
        return nil, errors.validation.InvalidInterfaceName
    end

    return true
end

---Construct a new `InterfaceName` from a string.
---
---This function throws if `name` is not a valid string.
---
---@param name string
---@return glacier.dbus.type.InterfaceName
function interface_name.from_str(name)
    assert(interface_name.validate(name))

    return InterfaceName_new(name)
end

---Construct a new `InterfaceName` from a string.
---
---@param name string
---@return glacier.dbus.type.InterfaceName? # Returns `nil` if the `name` wasn't a valid `InterfaceName`.
---@return string? # The error if `name` was rejected.
function interface_name.try_from_str(name)
    local ok, err = interface_name.validate(name)

    if not ok then
        return nil, err
    end

    return InterfaceName_new(name), nil
end

---@param value string|glacier.dbus.type.InterfaceName
---
---@return glacier.dbus.type.InterfaceName?
---@return string?
function interface_name.try_from(value)
    if type(value) == "string" then
        return interface_name.try_from_str(value)
    elseif _utils.is(value, InterfaceName) then
        ---@cast value glacier.dbus.type.InterfaceName
        return value
    end

    return nil, errors.type.Invalid
end

interface_name.InterfaceName = InterfaceName

return interface_name
