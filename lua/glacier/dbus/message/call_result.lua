local _errors = require("glacier.dbus.errors")
local _types = require("glacier.dbus.type")

---@class glacier.dbus.message.CallError
---@field _name glacier.dbus.type.InterfaceName
---@field _message? string
local CallError = {}
CallError.__index = CallError
CallError.__name = "dbus.connection.CallError"

---@param name string|glacier.dbus.type.InterfaceName
---@param message? string
function CallError.new(name, message)
    if type(name) == "string" then
        name = _types.interface_name.from_str(name)
    end

    assert(_types.is(name, _types.interface_name.InterfaceName), _errors.type.Invalid)

    --TODO: Check message type ?
    return setmetatable({
        _name = name,
        _message = message,
    }, CallError)
end

function CallError:name()
    return self._name
end

function CallError:name_str()
    return self._name:str()
end

function CallError:message()
    return self._message
end

function CallError.__eq(lhs, rhs)
    if lhs == nil or rhs == nil then
        return false
    elseif getmetatable(lhs) == CallError and getmetatable(rhs) == CallError then
        return lhs:name() == rhs:name() and lhs:message() == rhs:message()
    end

    return nil
end

function CallError:__tostring()
    if self._message then
        return ("%s: %s"):format(self:name_str(), self._message)
    else
        return "%s"
    end
end

---Result of a method call.
---@class glacier.dbus.message.CallResult
---@field _ok? glacier.dbus.type.Struct
---@field _error? glacier.dbus.message.CallError
local CallResult = {}
CallResult.__index = CallResult
CallResult.__name = "dbus.CallResult"

local function CallResult_ok(body)
    return setmetatable({
        _ok = body,
    }, CallResult)
end

local function CallResult_error(name, message)
    return setmetatable({
        _error = CallError.new(name, message),
    }, CallResult)
end

---@param message glacier.dbus.Message
local function CallResult_from_message(message)
    if message:type() == _types.message_type.Error then
        local name = message:error_name()
        local error_str
        if message.body and _types.is(message.body[1], _types.String) then
            error_str = message.body[1]:get()
        end

        return CallResult_error(name, error_str)
    else
        return CallResult_ok(message.body)
    end
end

function CallResult:ok()
    return self._ok
end

---@return glacier.dbus.message.CallError?
function CallResult:error()
    return self._error
end

function CallResult:is_ok()
    return self._error == nil
end

function CallResult:is_error()
    return self._error ~= nil
end

---@class glacier.dbus.message.call_result
local call_result = {
    CallResult = CallResult,
    CallError = CallError,
}

---@param body? glacier.dbus.type.Struct
function call_result.ok(body)
    return CallResult_ok(body)
end

---@param name glacier.dbus.type.InterfaceName
---@param message? string
function call_result.error(name, message)
    return CallResult_error(name, message)
end

function call_result.from_message(message)
    return CallResult_from_message(message)
end

return call_result
