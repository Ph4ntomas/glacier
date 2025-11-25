local errors = require("glacier.dbus.errors")
local _types = require("glacier.dbus.type")
local _match_rule = require("glacier.dbus.match_rule")

local _props_interface = "org.freedesktop.DBus.Properties"
local _props_signal = "PropertiesChanged"

---@class glacier.dbus.WeakProxy
---@field _proxy glacier.dbus.Proxy
local WeakProxy = {}
WeakProxy.__index = WeakProxy
WeakProxy.__name = "dbus.WeakProxy"
WeakProxy.__mode = "v"

---Create a weak version of a `Proxy`
---
---@param proxy glacier.dbus.Proxy
---
---@return glacier.dbus.WeakProxy
function WeakProxy.new(proxy)
    return setmetatable({
        _proxy = proxy,
    }, WeakProxy)
end

function WeakProxy:upgrade()
    if not self._proxy then
        return nil, errors.Expired
    end

    return self._proxy
end

---@class glacier.dbus.proxy.ProxyInternals
---@field connection glacier.dbus.Connection
---@field destination glacier.dbus.type.BusName
---@field path glacier.dbus.type.ObjectPath
---@field interface glacier.dbus.type.InterfaceName
---@field signal_matchers table<string, glacier.dbus.connection.Matcher[]>
---@field name_change? glacier.dbus.connection.Matcher
---@field property_change? glacier.dbus.connection.Matcher
---@field property_change_handler table<string, glacier.dbus.PropertyChangedHandler>

---@class glacier.dbus.Proxy
---@field _inner glacier.dbus.proxy.ProxyInternals
local Proxy = {}
Proxy.__index = Proxy
Proxy.__name = "dbus.Proxy"

---@param proxy glacier.dbus.Proxy
local function setup_property_change(proxy)
    local builder = _match_rule.builder()
    builder:with_sender(proxy:destination())
    builder:with_path(proxy:path())
    builder:with_interface(_props_interface)
    builder:with_member(_props_signal)
    local rule = builder:build()

    local weak = WeakProxy.new(proxy)

    local matcher = proxy:connection():add_matcher(rule, function(con, msg)
        local p = weak:upgrade()
        if not p then
            return false
        end

        p:_handle_properties_changed(msg.body[2])
        p:_handle_properties_invalidated(con, msg.body[3])

        return true
    end)

    return matcher
end

local function Proxy_new(connection, destination, path, interface)
    local internals = {
        connection = connection,
        destination = destination,
        path = path,
        interface = interface,
        signal_matchers = {},
        property_change_handler = {},
    }

    local ret = setmetatable({
        _inner = internals,
    }, Proxy)

    ret._inner.property_change = setup_property_change(ret)

    return ret
end

function Proxy:__gc()
    local signal_matchers = self._inner.signal_matchers
    for _, v in pairs(signal_matchers) do
        for _, matcher in ipairs(v) do
            self._inner.connection:remove_matcher(matcher)
        end
    end

    if self._inner.name_change then
        self._inner.connection:remove_matcher(self._inner.name_change)
    end

    self._inner.signal_matchers = {}
end

---Gets the `Conenction` associated with this `Proxy`.
---
---@return glacier.dbus.Connection
function Proxy:connection()
    return self._inner.connection
end

---Gets the `Destination` associated with this `Proxy`.
---
---@return glacier.dbus.type.BusName
function Proxy:destination()
    return self._inner.destination
end

---Gets the `ObjectPath` associated with this `Proxy`.
---
---@return glacier.dbus.type.ObjectPath
function Proxy:path()
    return self._inner.path
end

---Gets the `InterfaceName` associated with this `Proxy`.
---
---@return glacier.dbus.type.InterfaceName
function Proxy:interface()
    return self._inner.interface
end

---@alias glacier.dbus.OwnerChangedHandler fun(old: glacier.dbus.type.String, new: glacier.dbus.type.String)

---@param f? glacier.dbus.OwnerChangedHandler
function Proxy:on_owner_changed(f)
    if not f and self._inner.name_change then
        self._inner.connection:remove_matcher(self._inner.name_change)
        self._inner.name_change = nil
        return
    elseif not f then
        return
    end

    local handler = function(_, msg)
        f(msg.body[2]:get(), msg.body[3]:get())
    end

    if f and not self._inner.name_change then
        local builder = _match_rule.builder()
        builder:with_sender("org.freedesktop.DBus")
        builder:with_path("/org/freedesktop/DBus")
        builder:with_member("NameOwnerChanged")
        builder:with_interface("org.freedesktop.DBus")
        builder:with_arg(0, self:destination():str())
        local rule = builder:build()

        local matcher = self:connection():add_matcher(rule, handler)

        self._inner.name_change = matcher
    elseif f then
        self._inner.name_change:set_handler(handler)
    end
end

--------------------------
-- Properties           --
--------------------------

---@alias glacier.dbus.PropertyChangedHandler fun(name: string, value?: glacier.dbus.type.StrongType)

---@private
---
---@param name string
---@param value? glacier.dbus.type.Variant
function Proxy:_notify_property_changed(name, value)
    local handler = self._inner.property_change_handler[name]

    if handler then
        ---@diagnostic disable-next-line:cast-local-type
        value = value and value:get()
        handler(name, value)
    end
end

---@package
---@param changed glacier.dbus.type.Dict
function Proxy:_handle_properties_changed(changed)
    for n, v in pairs(changed:get()) do
        ---@cast v glacier.dbus.type.Variant

        self:_notify_property_changed(n, v)
    end
end

---@package
---@param c glacier.dbus.Connection
---@param invalidated glacier.dbus.type.Array
function Proxy:_handle_properties_invalidated(c, invalidated)
    local _ = c

    ---@type table<cqueues.promise, { name:string, pending:glacier.dbus.connection.PendingCall }>
    for _, n in ipairs(invalidated) do
        self:_notify_property_changed(n:get())
    end
end

-- TODO: Implement property caching
---@param name string Property name
---@param handler glacier.dbus.PropertyChangedHandler
function Proxy:on_property_change(name, handler)
    self._inner.property_change_handler[name] = handler
end

---@param name string Property name
---
---@return glacier.dbus.type.StrongType?
---@return glacier.dbus.message.CallError?
function Proxy:get_property(name)
    local body = _types.Struct({
        _types.String(self:interface():str()),
        _types.String(name),
    })

    local pending = self:connection():call_method(
        self:destination(),
        self:path(),
        "org.freedesktop.DBus.Properties",
        "Get",
        body
    )

    local res = pending:get() --[[@as glacier.dbus.message.CallResult]]

    if res:is_error() then
        return nil, res:error()
    end

    local v = res:ok()[1] --[[@as glacier.dbus.type.Variant]]

    return v:get()
end

---@param name string Property name
---
---@return glacier.dbus.connection.PendingCall
function Proxy:get_property_async(name)
    local body = _types.Struct({
        _types.String(self:interface():str()),
        _types.String(name),
    })

    return self:connection():call_method(
        self:destination(),
        self:path(),
        "org.freedesktop.DBus.Properties",
        "Get",
        body
    )
end

---@return glacier.dbus.type.Dict? --- A dictionary <String, Variant> describing the properties.
---@return glacier.dbus.message.CallError?
function Proxy:get_all_properties()
    local body = _types.Struct({
        _types.String(self:interface():str()),
    })

    local pending = self:connection():call_method(
        self:destination(),
        self:path(),
        "org.freedesktop.DBus.Properties",
        "GetAll",
        body
    )

    local res = pending:get() --[[@as glacier.dbus.message.CallResult]]

    if res:is_error() then
        return nil, res:error()
    end

    return res:ok()[1]
end

---@param name string Property name
---@param value glacier.dbus.type.StrongType Value to set. The value will be wrapped in a Variant before sending.
---
---@return glacier.dbus.type.StrongType
function Proxy:set_property(name, value)
    assert(_types.is_strong_type(value), errors.type.Invalid)
    value = _types.Variant(value)

    local body = _types.Struct({
        _types.String(self:interface():str()),
        _types.String(name),
        value,
    })

    local pending = self:connection():call_method(
        self:destination(),
        self:path(),
        "org.freedesktop.DBus.Properties",
        "Set",
        body
    )

    local res = pending:get()

    ---@diagnostic disable-next-line:need-check-nil
    return res:ok(), res:error()
end

---@alias glacier.dbus.SignalHandler fun(conn:glacier.dbus.Connection, signal_name: string, body?: glacier.dbus.type.Struct)

---Set a callback to receive signals from this `Proxy`.
---
---@param name string|glacier.dbus.type.MemberName
---@param handler glacier.dbus.SignalHandler
---@return glacier.dbus.Proxy
function Proxy:on_signal(name, handler)
    local builder = _match_rule.builder()
    builder:with_path(self:path())
    builder:with_sender(self:destination())
    builder:with_interface(self:interface())
    assert(builder:with_member(name))
    local rule = builder:build()

    if type(name) ~= "string" then
        name = name:str()
    end

    local matcher = self:connection():add_matcher(rule, function(c, msg)
        handler(c, msg:member():str(), msg.body)
        return true
    end)

    local matchers = self._inner.signal_matchers[name] or {}
    self._inner.signal_matchers[name] = matchers

    table.insert(matchers, matcher)

    return self
end

---Call the method `member`, and wait for a reply.
---
---@param member string|glacier.dbus.type.MemberName
---@param body? glacier.dbus.type.Struct
---
---@return glacier.dbus.message.CallResult
function Proxy:call(member, body)
    return assert(self:call_with_flags(member, nil, body))
end

---Call the method `member`, without waiting for a reply.
---
---The method will be called with the `no_reply` flag set.
---@param member string|glacier.dbus.type.MemberName
---@param body glacier.dbus.type.Struct|nil
function Proxy:call_noreply(member, body)
    self:call_with_flags_async(member, { no_reply = true }, body)
end

---Call the method `member`, setting `flags` on the message.
---
---@param member string|glacier.dbus.type.MemberName
---@param flags glacier.dbus.message.Flags?
---@return glacier.dbus.message.CallResult?
function Proxy:call_with_flags(member, flags, body)
    local pending = self:call_with_flags_async(member, flags, body)

    if pending then
        return pending:get()
    end

    return nil
end

---Call the method `member`, and return a `PendingCall` representing the result.
---
---@param member string|glacier.dbus.type.MemberName
---@param body glacier.dbus.type.Struct|nil
---
---@return glacier.dbus.connection.PendingCall
function Proxy:call_async(member, body)
    return self:call_with_flags_async(member, nil, body) --[[@as glacier.dbus.connection.PendingCall]]
end

---Call the method `member`, returning a `PendingCall` if `flags.no_reply` isn't set.
---
---@param member string|glacier.dbus.type.MemberName
---@param flags? glacier.dbus.message.Flags
---@param body? glacier.dbus.type.Struct
---@return glacier.dbus.connection.PendingCall?
function Proxy:call_with_flags_async(member, flags, body)
    if type(member) == "string" then
        member = _types.member_name.from_str(member)
    elseif not _types.is(member, _types.member_name.MemberName) then
        error(errors.type.Invalid)
    end

    return self:_call_with_flags_async(member, flags, body)
end

---Call the method `member`, returning a `PendingCall` if `flags.no_reply` isn't set.
---
---@param member glacier.dbus.type.MemberName
---@param flags? glacier.dbus.message.Flags
---@param body? glacier.dbus.type.Struct
---
---@return glacier.dbus.connection.PendingCall?
function Proxy:_call_with_flags_async(member, flags, body)
    return self._inner.connection:_call_method_with_flags(
        self._inner.destination,
        self._inner.path,
        self._inner.interface,
        member,
        flags,
        body
    )
end

---@class glacier.dbus.proxy.Builder
---@field connection glacier.dbus.Connection
---@field destination? glacier.dbus.type.BusName
---@field path? glacier.dbus.type.ObjectPath
---@field interface? glacier.dbus.type.InterfaceName
local Builder = {}
Builder.__index = Builder
Builder.__name = "dbus.proxy.Builder"

local function Builder_new(connection)
    return setmetatable({
        connection = connection,
    }, Builder)
end

---@diagnostic disable-next-line:duplicate-doc-alias
---@alias BusNames glacier.dbus.type.BusName|glacier.dbus.type.UniqueName|glacier.dbus.type.WellKnownName

---Set the `Proxy` destination.
---@param destination string|BusNames
---@return glacier.dbus.proxy.Builder?
---@return string?
function Builder:with_destination(destination)
    if type(destination) == "string" then
        local err
        ---@diagnostic disable-next-line:cast-local-type
        destination, err = _types.bus_name.try_from_str(destination)
        if not destination then
            return nil, err
        end
    elseif _types.is(destination, _types.bus_name.UniqueName) then
        ---@cast destination glacier.dbus.type.UniqueName
        destination = _types.bus_name.from_unique(destination)
    elseif _types.is(destination, _types.bus_name.WellKnownName) then
        ---@cast destination glacier.dbus.type.WellKnownName
        destination = _types.bus_name.from_wellknown(destination)
    elseif not _types.is(destination, _types.bus_name.BusName) then
        return nil, errors.type.Invalid
    end

    ---@cast destination glacier.dbus.type.BusName
    self.destination = destination
    return self
end

---Set the `Proxy` path.
---@param path string|glacier.dbus.type.ObjectPath
---@return glacier.dbus.proxy.Builder?
---@return string?
function Builder:with_path(path)
    if type(path) == "string" then
        local err
        ---@diagnostic disable-next-line:cast-local-type
        path, err = _types.object_path.try_from_str(path)
        if not path then
            return nil, err
        end
    elseif not _types.is(path, _types.ObjectPath) then
        return nil, errors.type.Invalid
    end

    ---@cast path glacier.dbus.type.ObjectPath
    self.path = path
    return self
end

---Set the `Proxy` interface.
---
---@param interface string|glacier.dbus.type.InterfaceName
---@return glacier.dbus.proxy.Builder?
---@return string?
function Builder:with_interface(interface)
    if type(interface) == "string" then
        local err
        ---@diagnostic disable-next-line:cast-local-type
        interface, err = _types.interface_name.try_from_str(interface)
        if not interface then
            return nil, err
        end
    elseif not _types.is(interface, _types.interface_name.InterfaceName) then
        return nil, errors.type.Invalid
    end

    ---@cast interface glacier.dbus.type.InterfaceName
    self.interface = interface
    return self
end

---Build the `Proxy`
---
---@return glacier.dbus.Proxy?
---@return string?
function Builder:build()
    if not self.destination then
        return nil, errors.MissingParameter
    end

    if not self.path then
        return nil, errors.MissingParameter
    end

    if not self.interface then
        return nil, errors.MissingParameter
    end

    return Proxy_new(self.connection, self.destination, self.path, self.interface), nil
end

---@class glacier.dbus.proxy
local proxy = {
    Proxy = Proxy,
}

---Initialize a `Proxy` builder.
---
---@param connection glacier.dbus.Connection
---
---@return glacier.dbus.proxy.Builder
function proxy.builder(connection)
    return Builder_new(connection)
end

return proxy
