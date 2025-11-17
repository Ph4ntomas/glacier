local errors = require("glacier.dbus.errors")

---@class glacier.dbus.type.MessageType
---@field private repr string
local MessageType = {}
MessageType.__index = MessageType
MessageType.__name = "dbus.type.MessageType"

---@package
---Construct a new `MessageType`.
---
---@param type string
---@return glacier.dbus.type.MessageType
local function MessageType_new(type)
    return setmetatable({ repr = type }, MessageType)
end

---Gets the `MessageType` as a string.
---@return string
function MessageType:str()
    return self.repr
end

function MessageType:__tostring()
    return ("MessageType{%s}"):format(self.repr)
end

---@param lhs glacier.dbus.type.MessageType
---@param rhs glacier.dbus.type.MessageType
---
---@return boolean
function MessageType.__eq(lhs, rhs)
    if lhs == nil and rhs == nil then
        return true
    elseif getmetatable(lhs) == MessageType and getmetatable(rhs) == MessageType then
        ---@cast lhs glacier.dbus.type.MessageType
        ---@cast rhs glacier.dbus.type.MessageType
        return lhs.repr == rhs.repr
    end

    return false
end

---@class glacier.dbus.type.message_type
local message_type = {
    MethodCall = MessageType_new("method_call"),
    MethodReturn = MessageType_new("method_return"),
    Signal = MessageType_new("signal"),
    Error = MessageType_new("error"),
    MessageType = MessageType,
}

---@package
---@enum ValidMessageType
local valid_msg_type = {
    method_call = "method_call",
    method_return = "method_return",
    signal = "signal",
    error = "error",
}

---Checks if a string is a valid `MessageType`
---
---@param type string
---@return boolean? # Returns `true` if `type` is a valid `MessageType`.
---@return string? # On error, the error description.
function message_type.validate(type)
    if not valid_msg_type[type] then
        return nil, errors.validation.InvalidMessageType
    end

    return true
end

---Converts a string to a `MessageType`.
---
---Throws if `type` is not a valid `MessageType`.
---@param type string
---@return glacier.dbus.type.MessageType
function message_type.from_str(type)
    assert(message_type.validate(type))

    return MessageType_new(type)
end

---Converts a string to a `MessageType`.
---@param type string
---@return glacier.dbus.type.MessageType? # Returns `nil` on error.
---@return string? # One error, returns the error description.
function message_type.try_from_str(type)
    local ok, err = message_type.validate(type)

    if not ok then
        return nil, err
    end

    return MessageType_new(type), nil
end

if _TEST then
    message_type._private = {
        valid_msg_type = valid_msg_type,
    }
end

return message_type
