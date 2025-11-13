local errors = require("glacier.dbus.errors")
local types = require("glacier.dbus.type")
local _message_type = require("glacier.dbus.type.message_type")

---@package
---@alias MatchRule glacier.dbus.MatchRule
---@diagnostic disable-next-line:duplicate-doc-alias
---@alias BusName glacier.dbus.type.BusName
---@diagnostic disable-next-line:duplicate-doc-alias
---@alias UniqueName glacier.dbus.type.UniqueName
---@diagnostic disable-next-line:duplicate-doc-alias
---@alias WellKnown glacier.dbus.type.WellKnownName

---@class glacier.dbus.match_rule
---@field MatchRule glacier.dbus.MatchRule
local match_rule = {}

local function validate_arg0namespace(name)
    local matches = 0
    name, matches = string.gsub(name, "^[%a_][%a%d_]*", "")

    if matches == 0 then
        return nil, errors.validation.InvalidArgNamespace
    end

    name, _ = string.gsub(name, "%.[%a_][%a%d_]*", "")

    if name ~= "" then
        return nil, errors.validation.InvalidArgNamespace
    end

    return true
end

local function validate_boolean(value)
    local strbool = tostring(value)
    if strbool ~= "true" and strbool ~= "false" then
        return nil, errors.validation.InvalidBoolean
    end
    return true
end

---@class glacier.dbus.MatchRule
---
---See [the spec] for more informations.
---
---NOTES:
---`path` and `path_namespace` are mutually exclusive.
---
---[the spec]: https://dbus.freedesktop.org/doc/dbus-specification.html#message-bus-messages
---
---@field private type? glacier.dbus.type.MessageType
---@field private sender? glacier.dbus.type.BusName
---@field private interface? glacier.dbus.type.InterfaceName
---@field private member? glacier.dbus.type.MemberName
---@field private path? glacier.dbus.type.ObjectPath
---@field private path_namespace? glacier.dbus.type.ObjectPath
---@field private destination? glacier.dbus.type.UniqueName
---@field private args? string[]
---@field private argspath? string[]
---@field private arg0namespace? string
---@field private eavesdrop? boolean
local MatchRule = {}
MatchRule.__index = MatchRule
MatchRule.__name = "dbus.match_rule.MatchRule"

---Create a new MatchRule.
---
---@param m MatchRule
---
---@return MatchRule
function MatchRule_new(m)
    m = m or {}

    setmetatable(m, MatchRule)

    return m
end

---Escape all 'magic character' from a string.
---
---@param str string
---
---@return string
local function _escaped(str)
    local ret = string.gsub(str, "([%^$()%.%[%]*%-+?])", function(e)
        return "%" .. e
    end)

    return ret
end

---@param argpath string
---@param value string
---@return boolean
local function _argpath_match(argpath, value)
    if argpath == value then
        return true
    end

    local pat = _escaped(argpath)
    if string.match(argpath, "/$") and string.match(value, "^" .. pat) then
        return true
    end

    pat = _escaped(value)
    if string.match(value, "/$") and string.match(argpath, "^" .. pat) then
        return true
    end

    return false
end

---Match a `Message` against this `MatchRule`.
---
---This function is meant to match a message after it was filtered by a Bus. As such:
--- - `sender` is ignored if its a well-known name, since a message `sender` field is always a
---   unique name.
--- - `destination` is ignored if the message destination is a well-known name, as the one in the
---   rule is a unique name.
---
---@param msg glacier.dbus.Message
---
---@return boolean
function MatchRule:match(msg)
    if self.type and self.type ~= msg:type() then
        return false
    end

    if self.sender and self.sender:is_unique() and self.sender:unique() ~= msg:sender() then
        return false
    end

    if self.interface and self.interface ~= msg:interface() then
        return false
    end

    if self.member and self.member ~= msg:member() then
        return false
    end

    if self.path and self.path ~= msg:path() then
        return false
    end

    if self.path_namespace then
        if not msg:path() then
            return false
        elseif not string.match(msg:path():get(), "^" .. self.path_namespace:get()) then
            return false
        end
    end

    if self.destination then
        local dest = msg:destination()

        if not dest then
            return false
        elseif dest:is_unique() and self.destination ~= dest:unique() then
            return false
        end
    end

    if self.args then
        for k, v in pairs(self.args) do
            local vstr = types.String(v)

            local msg_value = msg:arg(k - 1)
            if vstr ~= msg_value then
                return false
            end
        end
    end

    if self.argspath then
        for k, v in pairs(self.argspath) do
            local msg_value = msg:arg(k - 1) --[[@as glacier.dbus.type.String|glacier.dbus.type.ObjectPath]]

            if not (types.is(msg_value, types.String) or types.is(msg_value, types.ObjectPath)) then
                return false
            elseif not _argpath_match(v, msg_value:get()) then
                return false
            end
        end
    end

    if self.arg0namespace then
        local arg0 = msg:arg(0) --[[@as glacier.dbus.type.String]]
        local pat = _escaped(self.arg0namespace)

        if not types.is(arg0, types.String) then
            return false
        elseif not string.match(arg0:get(), "^" .. pat) and self.arg0namespace ~= arg0:get() then
            return false
        end
    end

    return true
end

---Return then `MatchRule` as a string.
---
---The generated string is stable (every element will always be in the same order).
---@return string
function MatchRule:str()
    local field_ordered = {
        "type",
        "sender",
        "interface",
        "member",
        "path",
        "path_namespace",
        "destination",
        "args",
        "argspath",
        "arg0namespace",
        "eavesdrop",
    }

    local str_table = {
        type = self.type and self.type:str(),
        sender = self.sender and self.sender:str(),
        interface = self.interface and self.interface:str(),
        member = self.member and self.member:str(),
        path = self.path and self.path:get(),
        path_namespace = self.path_namespace and self.path_namespace:get(),
        destination = self.destination and self.destination:str(),
        arg0namespace = self.arg0namespace,
    }

    if self.eavesdrop ~= nil then
        str_table.eavesdrop = self.eavesdrop
    end

    local rule_str = {}
    for k, v in pairs(str_table) do
        rule_str[k] = ("%s='%s'"):format(k, v)
    end

    if self.args then
        local args_rule = {}

        for i = 1, 64 do
            if self.args[i] then
                table.insert(args_rule, ("arg%d='%s'"):format(i - 1, self.args[i]))
            end
        end

        rule_str.args = table.concat(args_rule, ",")
    end

    if self.argspath then
        local args_rule = {}

        for i = 1, 64 do
            if self.argspath[i] then
                table.insert(args_rule, ("arg%dpath='%s'"):format(i - 1, self.argspath[i]))
            end
        end

        rule_str.args = table.concat(args_rule, ",")
    end

    local rule = {}
    for _, field in ipairs(field_ordered) do
        table.insert(rule, rule_str[field])
    end

    return table.concat(rule, ",")
end

---@class glacier.dbus.match_rule.Builder
---@field private type? glacier.dbus.type.MessageType
---@field private sender? glacier.dbus.type.BusName
---@field private interface? glacier.dbus.type.InterfaceName
---@field private member? glacier.dbus.type.MemberName
---@field private path? glacier.dbus.type.ObjectPath
---@field private path_namespace? glacier.dbus.type.ObjectPath
---@field private destination? glacier.dbus.type.UniqueName
---@field private args? string[]
---@field private argspath? string[]
---@field private arg0namespace? string
---@field private eavesdrop? boolean
local Builder = {}
Builder.__index = Builder
Builder.__name = "dbus.match_rule.Builder"

local function Builder_new()
    return setmetatable({
        args = {},
        argspath = {},
    }, Builder)
end

---@param message_type string|glacier.dbus.type.MessageType
---
---@return glacier.dbus.match_rule.Builder?
---@return string?
function Builder:with_type(message_type)
    if not message_type then
        self.type = nil
        return self
    end

    local err
    if type(message_type) == "string" then
        ---@diagnostic disable-next-line: cast-local-type
        message_type, err = types.message_type.try_from_str(message_type)

        if not message_type then
            return nil, err
        end
    elseif not types.is(message_type, _message_type.MessageType) then
        return nil, errors.type.Invalid
    end

    self.type = message_type

    return self
end

---@param sender string|BusName|UniqueName|WellKnown|nil
---@return glacier.dbus.match_rule.Builder?
---@return string?
function Builder:with_sender(sender)
    if not sender then
        self.sender = nil
        return self
    end

    local err
    if type(sender) == "string" then
        ---@diagnostic disable-next-line: cast-local-type
        sender, err = types.bus_name.try_from_str(sender)
        if not sender then
            return nil, err
        end
    else
        if types.is(sender, types.bus_name.UniqueName) then
            ---@diagnostic disable-next-line: cast-local-type,param-type-mismatch
            sender = types.bus_name.from_unique(sender)
        elseif types.is(sender, types.bus_name.WellKnownName) then
            ---@diagnostic disable-next-line: cast-local-type,param-type-mismatch
            sender = types.bus_name.from_wellknown(sender)
        elseif not types.is(sender, types.bus_name.BusName) then
            return nil, errors.type.Invalid
        end
    end

    ---@cast sender glacier.dbus.type.BusName
    self.sender = sender

    return self
end

---@param interface string|glacier.dbus.type.InterfaceName
---@return glacier.dbus.match_rule.Builder?
---@return string?
function Builder:with_interface(interface)
    if not interface then
        self.interface = nil
        return self
    end

    local err
    if type(interface) == "string" then
        ---@diagnostic disable-next-line: cast-local-type
        interface, err = types.interface_name.try_from_str(interface)
        if not interface then
            return nil, err
        end
    elseif not types.is(interface, types.interface_name.InterfaceName) then
        return nil, errors.type.Invalid
    end

    self.interface = interface

    return self
end

---comment
---@param member string|glacier.dbus.type.MemberName
---@return glacier.dbus.match_rule.Builder?
---@return string?
function Builder:with_member(member)
    if not member then
        self.member = nil
        return self
    end

    local err
    if type(member) == "string" then
        ---@diagnostic disable-next-line: cast-local-type
        member, err = types.member_name.try_from_str(member)
        if not member then
            return nil, err
        end
    elseif not types.is(member, types.member_name.MemberName) then
        return nil, errors.type.Invalid
    end

    self.member = member

    return self
end

---@param path string|glacier.dbus.type.ObjectPath
---
---@return glacier.dbus.match_rule.Builder?
---@return string?
function Builder:with_path(path)
    if not path then
        self.path = nil
        return self
    end

    local err
    if type(path) == "string" then
        ---@diagnostic disable-next-line: cast-local-type
        path, err = types.object_path.try_from_str(path)
        if not path then
            return nil, err
        end
    elseif not types.is(path, types.ObjectPath) then
        return nil, errors.type.Invalid
    end

    self.path = path
    self.path_namespace = nil

    return self
end

---@param path string|glacier.dbus.type.ObjectPath
---@return glacier.dbus.match_rule.Builder?
---@return string?
function Builder:with_path_namespace(path)
    if not path then
        self.path_namespace = nil
        return self
    end

    local err
    if type(path) == "string" then
        ---@diagnostic disable-next-line: cast-local-type
        path, err = types.object_path.try_from_str(path)
        if not path then
            return nil, err
        end
    elseif not types.is(path, types.ObjectPath) then
        return nil, errors.type.Invalid
    end

    self.path = nil
    self.path_namespace = path

    return self
end

---@param destination string|glacier.dbus.type.UniqueName
---
---@return glacier.dbus.match_rule.Builder?
---@return string?
function Builder:with_destination(destination)
    if not destination then
        self.destination = nil
        return self
    end

    local err
    if type(destination) == "string" then
        ---@diagnostic disable-next-line: cast-local-type
        destination, err = types.unique_name.try_from_str(destination)
        if not destination then
            return nil, err
        end
    elseif not types.is(destination, types.bus_name.UniqueName) then
        return nil, errors.type.Invalid
    end

    self.destination = destination

    return self
end

---@param pos integer
---@param arg string?
---@return glacier.dbus.match_rule.Builder?
---@return string?
function Builder:with_arg(pos, arg)
    pos = math.tointeger(pos) ---@diagnostic disable-line:cast-local-type

    if not pos or pos < 0 or pos > 63 then
        return nil, errors.validation.InvalidArgIndex
    end

    if not arg then
        self.args[pos + 1] = nil
    elseif type(arg) == "string" then
        self.args[pos + 1] = arg
    end

    return self
end

---@param pos integer
---@param argpath string?
---
---@return glacier.dbus.match_rule.Builder?
---@return string?
function Builder:with_arg_path(pos, argpath)
    pos = math.tointeger(pos) ---@diagnostic disable-line:cast-local-type

    if not pos or pos < 0 or pos > 63 then
        return nil, errors.validation.InvalidArgIndex
    end

    if not argpath then
        self.argspath[pos + 1] = nil
        return self
    end

    if type(argpath) == "string" then
        local to_check = string.match(argpath, "(.+)/$")
        if not to_check then
            to_check = argpath
        elseif to_check == "/" then -- this only happens if argpath is //
            return nil, errors.validation.InvalidObjectPath
        end

        local ok, err = types.object_path.validate(to_check)
        if not ok then
            return nil, err
        end

        self.argspath[pos + 1] = argpath
    end

    return self
end

---@param namespace string|nil
---@return glacier.dbus.match_rule.Builder?
---@return string?
function Builder:with_arg0namespace(namespace)
    if not namespace then
        self.arg0namespace = nil
        return self
    end

    local ok, err = validate_arg0namespace(namespace)
    if not ok then
        return nil, err
    end

    self.arg0namespace = namespace

    return self
end

---@param eavesdrop string|boolean|nil
---@return glacier.dbus.match_rule.Builder?
---@return string?
function Builder:with_eavesdrop(eavesdrop)
    if eavesdrop == nil then
        self.eavesdrop = nil
        return self
    end

    local ok, err = validate_boolean(eavesdrop)
    if not ok then
        return nil, err
    end

    if type(eavesdrop) == "string" then
        self.eavesdrop = eavesdrop == "true"
    else
        self.eavesdrop = not not eavesdrop
    end

    return self
end

---@return glacier.dbus.MatchRule
function Builder:build()
    if not next(self.args) then
        self.args = nil
    end

    if not next(self.argspath) then
        self.argspath = nil
    end

    return MatchRule_new({
        type = self.type,
        sender = self.sender,
        interface = self.interface,
        member = self.member,
        path = self.path,
        path_namespace = self.path_namespace,
        destination = self.destination,
        args = self.args,
        argspath = self.argspath,
        arg0namespace = self.arg0namespace,
        eavesdrop = self.eavesdrop,
    })
end

function match_rule.builder()
    return Builder_new()
end

local valid_fields = {
    ["type"] = true,
    ["sender"] = true,
    ["interface"] = true,
    ["member"] = true,
    ["path"] = true,
    ["path_namespace"] = true,
    ["destination"] = true,
    ["arg0namespace"] = true,
    ["eavesdrop"] = true,
}

---@param rule string
---@return MatchRule?
---@return string?
function match_rule.parse(rule)
    local split = {}
    local args = {}
    local argspath = {}
    local err_str = nil

    local subst = function(_, key, value)
        local argnum = string.match(key, "^arg(%d+)$")
        argnum = argnum and tonumber(argnum, 10)

        local argpathnum = string.match(key, "^arg(%d+)path$")
        argpathnum = argpathnum and tonumber(argpathnum, 10)

        if argnum and argnum < 64 and not args[argnum] then
            args[argnum] = value
        elseif argpathnum and argpathnum < 64 and not argspath[argpathnum] then
            argspath[argpathnum] = value
        elseif valid_fields[key] and not split[key] then
            split[key] = value
        else
            err_str = errors.validation.InvalidKey
            return "_" --- we use this to replace with something invalid so we can return the BadFormat error.
        end

        return ""
    end

    ---@diagnostic disable-next-line: redefined-local
    local rule, matches = string.gsub(rule, "^((.-)='(.-)')", subst)

    if matches == 0 then
        return nil, errors.validation.BadFormat
    end

    while rule ~= "" and err_str == nil do
        rule, matches = string.gsub(rule, "^,((.-)='(.-)')", subst)

        if matches == 0 then
            return nil, errors.validation.BadFormat
        end
    end

    if err_str then
        return nil, err_str
    end

    local builder = Builder_new()

    local ok, err
    ok, err = builder:with_type(split["type"])
    if not ok then
        return nil, err
    end

    ok, err = builder:with_sender(split["sender"])
    if not ok then
        return nil, err
    end

    ok, err = builder:with_interface(split["interface"])
    if not ok then
        return nil, err
    end

    ok, err = builder:with_member(split["member"])
    if not ok then
        return nil, err
    end

    ok, err = builder:with_path(split["path"])
    if not ok then
        return nil, err
    end

    ok, err = builder:with_path_namespace(split["path_namespace"])
    if not ok then
        return nil, err
    end

    ok, err = builder:with_destination(split["destination"])
    if not ok then
        return nil, err
    end

    for k, v in pairs(args) do
        ok, err = builder:with_arg(k, v)
        if not ok then
            return nil, err
        end
    end

    for k, v in pairs(argspath) do
        ok, err = builder:with_arg_path(k, v)
        if not ok then
            return nil, err
        end
    end

    ok, err = builder:with_arg0namespace(split["arg0namespace"])
    if not ok then
        return nil, err
    end

    ok, err = builder:with_eavesdrop(split["eavesdrop"])
    if not ok then
        return nil, err
    end

    return builder:build()
end

match_rule.MatchRule = MatchRule
match_rule.errors = errors

if _TEST then
    match_rule._private = {
        valid_msg_type = types._private.valid_msg_type,
    }
end

return match_rule
