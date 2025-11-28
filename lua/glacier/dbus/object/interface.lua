local _errors = require("glacier.dbus.errors")
local _types = require("glacier.dbus.type")
local _method = require("glacier.dbus.object.method")

---@class glacier.dbus.object.Interface
---@field _name glacier.dbus.type.InterfaceName
---@field _methods table<string, glacier.dbus.object.Method>
local Interface = {}
Interface.__index = Interface
Interface.__name = "dbus.object.Interface"

---@param iface glacier.dbus.object.Interface
---@return glacier.dbus.object.Interface
local function Interface_new(iface)
    return setmetatable(iface, Interface)
end

---@return glacier.dbus.type.InterfaceName
function Interface:name()
    return self._name
end

---@return string
function Interface:name_str()
    return self._name:str()
end

---@param context glacier.dbus.object.MethodContext
---@param message glacier.dbus.Message
---@return glacier.dbus.Message
function Interface:call(context, message)
    local name = message:member():str()
    local method = self._methods[name]

    if not method then
        return message:reply_error(_errors.dbus.UnknownMethod, name)
    end

    return method:call(context, message)
end

---@return string
function Interface:introspect()
    local iface_prefix = "    "
    local open_str = ("<interface name=%q>\n"):format(self:name_str())
    local close_str = "</interface>"

    local methods = {}
    for _, v in pairs(self._methods) do
        table.insert(methods, v:introspect())
    end

    local ret = iface_prefix .. open_str

    if #methods > 0 then
        ret = ret .. table.concat(methods, "\n") .. "\n"
    end

    ret = ret .. iface_prefix .. close_str
    return ret
end

---@class glacier.dbus.object.interface.Builder
---@field name glacier.dbus.type.InterfaceName
---@field methods table<string, glacier.dbus.object.Method>
local Builder = {}
Builder.__index = Builder
Builder.__name = "dbus.object.interface.Builder"

---@param name glacier.dbus.type.InterfaceName
---@return glacier.dbus.object.interface.Builder?
local function Builder_new(name)
    return setmetatable({
        name = name,
        methods = {},
    }, Builder)
end

---@param method glacier.dbus.object.Method
function Builder:with_method(method)
    if not _types.is(method, _method.Method) then
        return nil, _errors.type.Invalid
    end

    local name = method:name():str()
    self.methods[name] = method

    return self
end

function Builder:build()
    return Interface_new({
        _name = self.name,
        _methods = self.methods,
    })
end

local interface = {
    Interface = Interface,
}

---@param name string|glacier.dbus.type.InterfaceName
---@return glacier.dbus.object.interface.Builder?
---@return string?
function interface.builder(name)
    if type(name) == "string" then
        local err
        ---@diagnostic disable-next-line:cast-local-type
        name, err = _types.interface_name.try_from_str(name)
        if not name then
            return nil, err
        end
    elseif not _types.is(name, _types.InterfaceName) then
        return nil, _errors.type.Invalid
    end

    ---@cast name glacier.dbus.type.InterfaceName
    return Builder_new(name), nil
end

return interface
