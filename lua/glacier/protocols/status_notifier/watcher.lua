local Connection = require("glacier.dbus.connection")
local Interface = require("glacier.dbus.object.interface")
local MatchRule = require("glacier.dbus.match_rule")
local Method = require("glacier.dbus.object.method")
local Property = require("glacier.dbus.object.property")
local Proxy = require("glacier.dbus.proxy")
local Signal = require("glacier.dbus.object.signal")
local Types = require("glacier.dbus.type")

local _config = require("glacier.protocols.status_notifier.config")

local _object_path = _config.watcher.object
local _service_name = _config.watcher.service
local _interface_name = _config.watcher.interface
local _protocol_version = _config.protocol_version -- This is hardcoded as 0, for some reason.

---@class glacier.protocols.status_notifier.watcher
local watcher = {}

---------------------
-- Type definition --
---------------------

---@class glacier.protocols.status_notifier.Watcher
---@field private _connection glacier.dbus.Connection
---@field private _items table<string, string>
---@field private _hosts table<string, string>
---@field private _interface glacier.dbus.object.Interface
---@field private _emitter glacier.dbus.object.SignalEmitter
local Watcher = {}
Watcher.__index = Watcher
Watcher.__name = "g.p.status_notifier.Watcher"

---@package
---@class glacier.protocols.status_notifier.WeakWatcher
---@field private _watcher glacier.protocols.status_notifier.Watcher
local WeakWatcher = {}
WeakWatcher.__index = WeakWatcher
WeakWatcher.__name = "glacier.status_notifier.WeakWatcher"
WeakWatcher.__mode = "v"

---@class glacier.protocols.status_notifier.WatcherProxy
---@field private _proxy glacier.dbus.Proxy
local WatcherProxy = {}
WatcherProxy.__index = WatcherProxy
WatcherProxy.__name = "g.p.status_notifier.WatcherProxy"

---@param _watcher glacier.protocols.status_notifier.Watcher
---@return glacier.protocols.status_notifier.WeakWatcher
function WeakWatcher.new(_watcher)
    return setmetatable({ _watcher = _watcher }, WeakWatcher)
end

---@return glacier.protocols.status_notifier.Watcher?
function WeakWatcher:upgrade()
    return self._watcher
end

------------------
-- Watcher Impl --
------------------

---------------
-- DBUS Impl --
---------------

local _signals = {
    Item = {
        Registered = "StatusNotifierItemRegistered",
        Unregistered = "StatusNotifierItemUnregistered",
    },
    Host = {
        Registered = "StatusNotifierHostRegistered",
        Unregistered = "StatusNotifierHostUnregistered",
    },
}

local _properties = {
    RegisteredItems = "RegisteredStatusNotifierItems",
    IsHostRegistered = "IsStatusNotifierHostRegistered",
}

---@param weak glacier.protocols.status_notifier.WeakWatcher
---@return glacier.dbus.object.Method
local function m_RegisterStatusNotifierItem(weak)
    return Method.builder("RegisterStatusNotifierItem")
        :add_input("service", Types.String)
        :with_handler(function(ctx, service)
            local watch = assert(weak:upgrade())

            local sender = ctx:message():sender():str()

            ---@cast service glacier.dbus.type.String
            watch:_on_register_item(sender, service:get())
        end)
        :build()
end

---@param weak glacier.protocols.status_notifier.WeakWatcher
---@return glacier.dbus.object.Method
local function m_RegisterStatusNotifierHost(weak)
    return Method.builder("RegisterStatusNotifierHost")
        :add_input("service", Types.String)
        :with_handler(function(ctx, service)
            local watch = assert(weak:upgrade())

            local sender = ctx:message():sender():str()

            ---@cast service glacier.dbus.type.String
            watch:_on_register_host(sender, service:get())
        end)
        :build()
end

local function p_RegisteredStatusNotifierItems()
    return Property.builder(_properties.RegisteredItems)
        :writeable(false)
        :build(Types.Array(Types.String))
end

local function p_IsStatusNotifierHostRegistered()
    return Property.builder(_properties.IsHostRegistered)
        :writeable(false)
        :build(Types.Boolean(false))
end

local function p_ProtocolVersion()
    return Property.builder("ProtocolVersion")
        :writeable(false)
        :build(Types.Int32(_protocol_version))
end

local function s_StatusNotifierItemRegistered()
    return Signal.builder(_signals.Item.Registered):add_argument("service", Types.String):build()
end

local function s_StatusNotifierItemUnregistered()
    return Signal.builder(_signals.Item.Unregistered):add_argument("service", Types.String):build()
end

local function s_StatusNotifierHostRegistered()
    return Signal.builder(_signals.Host.Registered):build()
end

local function s_StatusNotifierHostUnregistered()
    return Signal.builder(_signals.Host.Unregistered):build()
end

---@param weak glacier.protocols.status_notifier.WeakWatcher
---@return glacier.dbus.object.Interface
local function build_interface(weak)
    return Interface.builder(_interface_name)
        :with_method(m_RegisterStatusNotifierItem(weak))
        :with_method(m_RegisterStatusNotifierHost(weak))
        :with_property(p_RegisteredStatusNotifierItems())
        :with_property(p_IsStatusNotifierHostRegistered())
        :with_property(p_ProtocolVersion())
        :with_signal(s_StatusNotifierItemRegistered())
        :with_signal(s_StatusNotifierItemUnregistered())
        :with_signal(s_StatusNotifierHostRegistered())
        :with_signal(s_StatusNotifierHostUnregistered())
        :build()
end

---------------------
-- Private Methods --
---------------------

function Watcher:_watch_lifetime()
    local weak = WeakWatcher.new(self)

    local builder = MatchRule.builder()
    builder:with_sender("org.freedesktop.DBus")
    builder:with_path("/org/freedesktop/DBus")
    builder:with_member("NameOwnerChanged")
    builder:with_interface("org.freedesktop.DBus")

    local rule = builder:build()

    self._lifetime_watcher = self._connection:add_matcher(rule, function(_, msg)
        local watch = weak:upgrade()
        if watch then
            return watch:_on_watch_notify(msg.body[1]:get())
        end

        return false
    end)
end

---@param name string
---@return boolean
function Watcher:_on_watch_notify(name)
    local matched = false

    if self._items[name] then
        matched = true
        self:_on_unregister_item(name)
    end

    if self._hosts[name] then
        matched = true
        self:_on_unregister_host(name)
    end

    return matched
end

---@param sender string
---@param item string
function Watcher:_on_register_item(sender, item)
    if string.match(item, "^/") then
        item = sender .. item
        if self._items[sender] then
            return
        end
        self._items[sender] = item
    else
        if self._items[item] then
            return
        end
        self._items[item] = item
    end

    self:_update_item_prop()
    self._interface:emit(
        self._emitter,
        _signals.Item.Registered,
        Types.Struct({ Types.String(item) })
    )
end

---@param item string
function Watcher:_on_unregister_item(item)
    local item_name = self._items[item]
    self._items[item] = nil

    self:_update_item_prop()
    self._interface:emit(
        self._emitter,
        _signals.Item.Unregistered,
        Types.Struct({ Types.String(item_name) })
    )
end

function Watcher:_update_item_prop()
    local new_item_list = Types.Array(Types.String)

    for _, v in pairs(self._items) do
        table.insert(new_item_list, Types.String(v))
    end

    self._interface:set(self._emitter, _properties.RegisteredItems, new_item_list)
end

---@param host string
function Watcher:_on_register_host(sender, host)
    if string.match(host, "^/") then
        host = sender .. host
        self._hosts[sender] = host
    else
        self._hosts[host] = host
    end

    self:_update_host_prop()
    self._interface:emit(self._emitter, _signals.Host.Registered)
end

---@param host string
function Watcher:_on_unregister_host(host)
    self._hosts[host] = nil

    self:_update_host_prop()
    self._interface:emit(self._emitter, _signals.Host.Unregistered)
end

function Watcher:_update_host_prop()
    local k, _ = next(self._hosts)

    self._interface:set(self._emitter, _properties.IsHostRegistered, Types.Boolean(k ~= nil))
end

--------------
-- Lifetime --
--------------

---@param connection glacier.dbus.Connection
---@return glacier.protocols.status_notifier.Watcher
function Watcher.new(connection)
    local _watcher = setmetatable({
        _items = {},
        _item_translate = {},
        _hosts = {},
        _host_translate = {},
    }, Watcher)
    local weak = WeakWatcher.new(_watcher)

    local iface = assert(build_interface(weak), "Could not build interface")

    local interface = connection:router():get_interface(_object_path, _interface_name)
    if interface then
        error("Interface is already registered")
    end

    assert(connection:router():interface_at(_object_path, iface))
    local reply = connection:request_name(_service_name)
    if
        reply == Connection.RequestNameReply.already_owner
        or reply == Connection.RequestNameReply.exists
    then
        error("Name already owned.")
    end

    _watcher._connection = connection
    _watcher._interface =
        assert(_watcher._connection:router():get_interface(_object_path, _interface_name))
    _watcher._emitter = assert(_watcher._connection:router():emitter_for(_object_path))
    _watcher:_watch_lifetime()

    return _watcher
end

function Watcher:__gc()
    if self._connection then
        self._connection:release_name(_service_name)
        if self._lifetime_watcher then
            self._connection:remove_matcher(self._lifetime_watcher)
            self._lifetime_watcher = nil
        end
        self._connection = nil
    end
end

----------------
-- Proxy Impl --
----------------

-------------
-- Methods --
-------------

---@param service string
function WatcherProxy:register_item(service)
    self._proxy:call(
        "RegisterStatusNotifierItem",
        Types.Struct({
            Types.String(service),
        })
    )
end

---@param service string
function WatcherProxy:register_host(service)
    self._proxy:call(
        "RegisterStatusNotifierHost",
        Types.Struct({
            Types.String(service),
        })
    )
end

----------------
-- Properties --
----------------

---@return string[] # Registered items' service name.
function WatcherProxy:get_registered_items()
    local value = assert(self._proxy:get_property("RegisteredStatusNotifierItems")) --[[@as glacier.dbus.type.Array]]

    local ret = {}
    for _, v in ipairs(value:get()) do
        ---@cast v glacier.dbus.type.String
        table.insert(ret, v:get())
    end

    return ret
end

---@return boolean
function WatcherProxy:is_host_registered()
    local value = assert(self._proxy:get_property("IsStatusNotifierHostRegistered")) --[[@as glacier.dbus.type.Boolean]]

    return value:get()
end

---@return number
function WatcherProxy:get_protocol_version()
    local value = assert(self._proxy:get_property("ProtocolVersion")) --[[@as glacier.dbus.type.Int32]]

    return value:get()
end

-------------
-- Signals --
-------------

---@param f fun(service: string)
function WatcherProxy:on_item_registered(f)
    self._proxy:on_signal("StatusNotifierItemRegistered", function(_, _, body)
        f(body[1]:get())
    end)
end

---@param f fun(service: string)
function WatcherProxy:on_item_unregistered(f)
    self._proxy:on_signal("StatusNotifierItemUnregistered", function(_, _, body)
        f(body[1]:get())
    end)
end

---@param f fun()
function WatcherProxy:on_host_registered(f)
    self._proxy:on_signal("StatusNotifierItemUnregistered", function(_, _)
        f()
    end)
end

---@param f fun()
function WatcherProxy:on_host_unregistered(f)
    self._proxy:on_signal("StatusNotifierItemUnregistered", function(_, _)
        f()
    end)
end

--------------
-- Lifetime --
--------------

---@param connection glacier.dbus.Connection
---@return glacier.protocols.status_notifier.WatcherProxy
function WatcherProxy.new(connection)
    local proxy = Proxy.builder(connection)
        :with_destination(_config.watcher.service)
        :with_path(_config.watcher.object)
        :with_interface(_config.watcher.interface)
        :build()

    return setmetatable({
        _proxy = proxy,
    }, WatcherProxy) --[[@as glacier.protocols.status_notifier.WatcherProxy]]
end

-----------
-- Other --
-----------

watcher.Watcher = Watcher
watcher.Proxy = WatcherProxy

return watcher
