local _signature = require("glacier.dbus.type.signature")

---@enum glacier.dbus.object.Direction
local Direction = {
    In = 0,
    Out = 1,
}

---@class glacier.dbus.object.Arg
---@field name? string
---@field type glacier.dbus.type.StrongType
---@field direction glacier.dbus.object.Direction
local Arg = {}
Arg.__index = Arg
Arg.__name = "dbus.object.Arg"

---@return glacier.dbus.object.Arg
function Arg.new(name, type, direction)
    return setmetatable({
        name = name,
        type = type,
        direction = direction,
    }, Arg)
end

---@return glacier.dbus.type.Signature
function Arg:signature()
    return self.type:signature() --[[@as glacier.dbus.type.Signature]]
end

---@return string
function Arg:introspect(no_direction)
    local prefix = "        "

    local attributes = {}

    if self.name then
        table.insert(attributes, ("name=%q"):format(self.name))
    end

    local type = self.type:signature():compute_str(1)
    table.insert(attributes, ("type=%q"):format(type))

    if not no_direction then
        local direction = self.direction == Direction.In and "in" or "out"
        table.insert(attributes, ("direction=%q"):format(direction))
    end

    local str = ("<arg %s/>"):format(table.concat(attributes, " "))

    return prefix .. str
end

local argument = {
    Arg = Arg,
    Direction = Direction,
}

---@param argpack glacier.dbus.object.Arg[]
---
---@return glacier.dbus.type.Signature?
function argument.signature(argpack)
    if not argpack then
        return nil
    end

    local sigs = {}
    for _, arg in ipairs(argpack) do
        table.insert(sigs, arg:signature())
    end

    return _signature.Struct(sigs)
end

---@param name? string
---@param type glacier.dbus.type.StrongType
---@param direction glacier.dbus.object.Direction
---
---@return glacier.dbus.object.Arg
function argument.new(name, type, direction)
    return Arg.new(name, type, direction)
end

return argument
