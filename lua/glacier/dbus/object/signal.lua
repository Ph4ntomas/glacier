local _errors = require("glacier.dbus.errors")
local _types = require("glacier.dbus.type")
local _args = require("glacier.dbus.object.argument")

---@class glacier.dbus.object.Signal
---@field _name glacier.dbus.type.MemberName
---@field _sig glacier.dbus.type.Signature
---@field _args glacier.dbus.object.Arg[]
local Signal = {}
Signal.__index = Signal
Signal.__name = "dbus.object.Signal"

local function Signal_new(name, args)
    return setmetatable({
        _name = name,
        _sig = _args.signature(args),
        _args = args,
    }, Signal)
end

---@return glacier.dbus.type.MemberName
function Signal:name()
    return self._name
end

---@param body? glacier.dbus.type.Struct
function Signal:check_body(body)
    if not body or not self._sig then
        return true
    end

    return body:signature() == self._sig
end

---@return string
function Signal:introspect()
    local signal_prefix = "      "
    local open_str = ("<signal name=%q>\n"):format(self._name:str())
    local close_str = "</signal>"
    local empty_str = ("<signal name=%q/>"):format(self._name:str())

    local args = {}
    if self._args then
        for _, v in ipairs(self._args) do
            table.insert(args, v:introspect(true))
        end
    end

    if #args == 0 then
        return signal_prefix .. empty_str
    end

    local ret = signal_prefix .. open_str
    if #args > 0 then
        ret = ret .. table.concat(args, "\n") .. "\n"
    end

    return ret .. signal_prefix .. close_str
end

---@class glacier.dbus.object.signal.Builder
---@field name glacier.dbus.type.MemberName
---@field args glacier.dbus.object.Arg[]
local Builder = {}
Builder.__index = Builder
Builder.__name = "dbus.object.Signal"

---Set the name of a `Signal`.
---@param name string|glacier.dbus.type.MemberName
---
---@return glacier.dbus.object.signal.Builder?
---@return string?
function Builder:with_name(name)
    local err
    ---@diagnostic disable-next-line:cast-local-type
    name, err = _types.member_name.try_from(name)
    if not name then
        return nil, err
    end

    ---@cast name glacier.dbus.type.MemberName
    self.name = name
    return self
end

---Add an argument to the `Signal`
---@param name string
---@param arg_type? glacier.dbus.type.StrongType
---
---@return glacier.dbus.object.signal.Builder?
---@return string?
---
---@overload fun(self:glacier.dbus.object.signal.Builder, type: glacier.dbus.type.StrongType):glacier.dbus.object.signal.Builder
function Builder:add_argument(name, arg_type)
    ---@type string|nil
    local arg_name = name

    if arg_type == nil then
        arg_type = name --[[@as glacier.dbus.type.StrongType]]
        arg_name = nil
    end

    if not _types.is_strong_type(arg_type) then
        return nil, _errors.type.Invalid
    end

    self.args = self.args or {}
    table.insert(self.args, _args.new(arg_name, arg_type, _args.Direction.Out))

    return self
end

function Builder:build()
    return Signal_new(self.name, self.args)
end

---@return glacier.dbus.object.signal.Builder
local function Builder_new()
    return setmetatable({}, Builder)
end

local signal = {
    Signal = Signal,
    Builder = Builder,
}

---@param name string|glacier.dbus.type.MemberName
---
---@return glacier.dbus.object.signal.Builder?
---@return string?
function signal.builder(name)
    local ret = Builder_new()

    return ret:with_name(name)
end

return signal
