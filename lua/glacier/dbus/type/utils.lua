local _type = type

---@class glacier.dbus.type.util
local util = {}

---Checks if a value `v` has a specific type `t` as its metatable.
---
---@param value any Value to compare against a specific type.
---@param type any Type.
function util.is(value, type)
    return _type(value) == "table" and getmetatable(value) == type
end

return util
