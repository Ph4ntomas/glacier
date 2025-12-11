local Proxy = require("glacier.dbus.proxy")
local Types = require("glacier.dbus.type")

local _config = require("glacier.protocols.status_notifier.config")

---@class glacier.status_notifier.WatcherProxy
---@field private _proxy glacier.dbus.Proxy
local WatcherProxy = {}
WatcherProxy.__index = WatcherProxy
WatcherProxy.__name = "glacier.status_notifier.WatcherProxy"

---@param connection glacier.dbus.Connection
function WatcherProxy.new(connection)
    local proxy = Proxy.builder(connection)
        :with_destination(_config.watcher.service)
        :with_path(_config.watcher.object)
        :with_interface(_config.watcher.interface)
        :build()

    return setmetatable({
        _proxy = proxy,
    }, WatcherProxy)
end

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

return WatcherProxy
