local _errors = require("glacier.dbus.errors")
local _types = require("glacier.dbus.type")

---@class glacier.dbus.object.internals
local internals = {}

---@param path string|glacier.dbus.type.ObjectPath
---
---@return string?
---@return string?
function internals.check_path(path)
    if type(path) == "string" then
        local err
        ---@diagnostic disable-next-line:cast-local-type
        path, err = _types.object_path.try_from_str(path)
        if not path then
            return nil, err
        end
    elseif not _types.is(path, _types.ObjectPath) then
        return nil, _errors.type.Invalid
    end

    ---@cast path glacier.dbus.type.ObjectPath

    return path:get(), nil
end

return internals
