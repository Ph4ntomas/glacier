local errors = require("glacier.dbus.errors")
local _utils = require("glacier.dbus.type.utils")

---@class glacier.dbus.type.MemberName
---@field private repr string
local MemberName = {}
MemberName.__index = MemberName
MemberName.__name = "dbus.type.MemberName"

---Construct a new `MemberName` from a string.
---
---@param name string
---@return glacier.dbus.type.MemberName
local function MemberName_new(name)
    return setmetatable({ repr = name }, MemberName)
end

---Gets the `MemberName`, as a string.
---@return string
function MemberName:str()
    return self.repr
end

function MemberName:__tostring()
    return ("MemberName{%s}"):format(self.repr)
end

function MemberName.__eq(lhs, rhs)
    if lhs == nil and rhs == nil then
        return true
    elseif getmetatable(lhs) == MemberName and getmetatable(rhs) == MemberName then
        ---@cast lhs glacier.dbus.type.MemberName
        ---@cast rhs glacier.dbus.type.MemberName
        return lhs.repr == rhs.repr
    end

    return false
end

---@class glacier.dbus.type.member_name
local member_name = {}

---Checks that a string is a valide `MemberName`
---@param name string
---@return boolean? # Returns `true` if `name` is a valid `MemberName`
---@return string? # On error, the error string.
function member_name.validate(name)
    if string.len(name) > 255 then
        return nil, errors.validation.NameTooLong
    end

    local match = string.match(name, "^[%a_][%a%d_]*$")
    if not match then
        return nil, errors.validation.InvalidMemberName
    end
    return true
end

---Converts a string to a `MemberName`.
---
---This function throws if `name` isn't valid.
---@param name string
---@return glacier.dbus.type.MemberName
function member_name.from_str(name)
    assert(member_name.validate(name))

    return MemberName_new(name)
end

---Converts a string to a `MemberName`.
---
---@param name string
---@return glacier.dbus.type.MemberName? # Returns `nil` on error.
---@return string? # On error, returns the error description.
function member_name.try_from_str(name)
    local ok, err = member_name.validate(name)

    if not ok then
        return nil, err
    end

    return MemberName_new(name), nil
end

---@param value string|glacier.dbus.type.MemberName
---
---@return glacier.dbus.type.MemberName?
---@return string?
function member_name.try_from(value)
    if type(value) == "string" then
        return member_name.try_from_str(value)
    elseif _utils.is(value, MemberName) then
        ---@cast value glacier.dbus.type.MemberName
        return value
    end

    return nil, errors.type.Invalid
end

member_name.MemberName = MemberName

return member_name
