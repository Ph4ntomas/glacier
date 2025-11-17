---@class glacier.dbus.type.StrongType
local StrongType = { __name = "StrongType" }

local StrongTypeMarker = {}

StrongType.__strong_type = StrongTypeMarker
StrongType.__index = StrongType

---@param name string
---@param sig? glacier.dbus.type.Signature
function StrongType:new_type(name, sig)
    self.__index = self
    return setmetatable({
        __name = name,
        __signature = sig,
        __call = self.__call,
    }, self)
end

---Initialize the `StrongType`.
---
---This function must be called in the deriving class `new` function.
---@generic T:glacier.dbus.type.StrongType
---@param o T
---@return T
function StrongType:super(o)
    o = o or {}

    self.__index = self
    setmetatable(o, self)

    return o
end

---Initialize the `StrongType`
---
---@generic T:glacier.dbus.type.StrongType
---@param v T
---@return T
function StrongType:new(v) ---@diagnostic disable-line: unused-local
    error("StrongType:new must be implemented by deriving class.")
end

---Call the constructor of a strong_type.
---
---@generic Ret:glacier.dbus.type.StrongType
---@param ... unknown
---@return Ret # Return the result of calling the `new` function while forwarding any parameters.
function StrongType:__call(...)
    return self:new(...)
end

---Get the value of a `StrongType`.
function StrongType:get()
    error("StrongType:set must be implemented by deriving class.")
end

---Validate value.
---
---This function must be implemented by child class. The default one will always fail
---@generic T
---@param v T
---@return boolean # True on success, false otherwise.
---@return string? # On error, the reason for the validation failure.
function StrongType:validate(v) ---@diagnostic disable-line: unused-local
    return false, "StrongType:validate must be implemented by deriving class."
end

---Set the `StrongType` value.
---
---The value is validated by `StrongType:validate` before being stored in the object.
---
---@generic T
---@param v T
function StrongType:set(v) ---@diagnostic disable-line: unused-local
    error("StrongType:set must be implemented by deriving class.")
end

---Checks if the current value is of type `type`.
---@generic T:glacier.dbus.type.StrongType
---@param type T A StrongType to check against.
function StrongType:is(type)
    return getmetatable(self) == type
end

---@return boolean # True if the type if a container type.
function StrongType:is_container()
    return false
end

---Returns the current type signature.
---
---While this function can return signatures for all basic type before any value is built,
---Container type (with the exception of Variant) don't have a signature set on their types,
---only on values.
---
---@return glacier.dbus.type.Signature? # If the signature is known, returns it.
function StrongType:signature()
    if self:is_value() then
        return getmetatable(self).__signature
    else
        ---@diagnostic disable-next-line: undefined-field
        return self.__signature
    end
end

---@generic T: glacier.dbus.type.StrongType
---@param self T
---@return T
function StrongType:get_type()
    return getmetatable(self)
end

---@return boolean # Returns true if the current object is a value.
function StrongType:is_value()
    return getmetatable(self) ~= StrongType
end

---@param v any
---
---@return boolean
local function is_strong_type(v)
    if type(v) ~= "table" then
        return false
    end

    local mt = getmetatable(v)
    return mt ~= nil and mt.__strong_type == StrongTypeMarker
end

---@param v any
---
---@return boolean
local function is_basic_type(v)
    return is_strong_type(v) and not v:is_container()
end

---@param v any
---
---@return boolean
local function is_strong_value(v)
    return is_strong_type(v) and v:is_value()
end

------------------------------
-- Compound Types           --
------------------------------

---@class glacier.dbus.type.StrongContainer: glacier.dbus.type.StrongType
local StrongContainer = StrongType:new_type("StrongContainer")

---Initialize the `StrongContainer`.
---
---This function must be called in the deriving class `new` function.
---@generic T: glacier.dbus.type.StrongContainer
---@param o T
---@return T
function StrongContainer:super(o)
    o = o or {}

    self.__index = function(t, idx)
        local v = self[idx]
        if v then
            return v
        end

        return self.__container_index(t, idx)
    end

    setmetatable(o, self)
    return o
end

---@param idx any
function StrongContainer:__container_index(idx) ---@diagnostic disable-line:unused-local
    error("StrongContainer:__container_index must be implemented by deriving class.")
end

function StrongContainer:signature()
    error("StrongContainer:signature must be implemented by deriving class.")
end

function StrongContainer:is_value()
    return getmetatable(self) ~= StrongContainer
end

---@return boolean
function StrongContainer:is_container()
    return true
end

---@class glacier.dbus.type.strong_type
return {
    StrongType = StrongType,
    StrongContainer = StrongContainer,
    is_strong_type = is_strong_type,
    is_strong_value = is_strong_value,
    is_basic_type = is_basic_type,
}
