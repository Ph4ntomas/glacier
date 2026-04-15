local Connection = require("glacier.dbus.connection")

local dbusmenu = require("glacier.protocols.status_notifier.dbusmenu")
local DBusMenuProxy = dbusmenu.Proxy
local ItemProxy = require("glacier.protocols.status_notifier.item").Proxy
local Watcher = require("glacier.protocols.status_notifier.watcher")

local _config = require("glacier.protocols.status_notifier.config")

---@class glacier.protocols.status_notifier.host
local host = {}

---------------------
-- Type definition --
---------------------

---@enum glacier.protocols.status_notifier.host.ItemStatus
local item_status = {
    passive = "passive",
    active = "active",
    needs_attention = "needsattention",
    unknown = "unknown",
}

---@class glacier.protocols.status_notifier.host.menu_signal.LayoutUpdated
---@field revision integer
---@field parent_node integer

---@class glacier.protocols.status_notifier.host.menu_signal.PropertiesUpdated
---@field updates table<integer, glacier.protocols.status_notifier.layout.Properties>
---@field removal table<integer, string[]>

---@class glacier.protocols.status_notifier.host.MenuSignal
---@field layout_updated? glacier.protocols.status_notifier.host.menu_signal.LayoutUpdated
---@field properties_updated? glacier.protocols.status_notifier.host.menu_signal.PropertiesUpdated

---@class glacier.protocols.status_notifier.host.Menu
---@field private _proxy glacier.protocols.status_notifier.DBusMenuProxy
local Menu = {}

---@class glacier.protocols.status_notifier.host.ItemSignal
---@field new_title? {}
---@field new_icon? {}
---@field new_attention_icon? {}
---@field new_overlay_icon? {}
---@field new_tooltip? {}
---@field new_menu? {}
---@field new_status? glacier.protocols.status_notifier.host.ItemStatus

---@class glacier.protocols.status_notifier.host.Item
---@field private _bus_id string,
---@field private _destination string
---@field private _proxy glacier.protocols.status_notifier.ItemProxy
local Item = {}

---@class glacier.protocols.status_notifier.host.Event
---@field registered? glacier.protocols.status_notifier.host.Item
---@field unregistered? string
---@field error? string

---@class glacier.protocols.status_notifier.Host
---@field private _connection glacier.dbus.Connection
---@field private _watcher_proxy glacier.protocols.status_notifier.WatcherProxy
---@field private _name string
local Host = {}
Host.__index = Host
Host.__name = "g.p.status_notifier.Host"

---------------
-- Menu Impl --
---------------

-------------------
-- Public Method --
-------------------

function Menu:proxy()
    return self._proxy
end

---@param node_id integer
function Menu:click(node_id)
    self._proxy:event(node_id, dbusmenu.Event.clicked, 0, 0)
end

---@param node_id integer
function Menu:hover(node_id)
    self._proxy:event(node_id, dbusmenu.Event.hovered, 0, 0)
end

---@param node_id integer
function Menu:about_to_show(node_id)
    self._proxy:about_to_show(node_id)
end

---@param node_id integer
---@param depth integer
---@param names? string[]
---@return integer? revision
---@return glacier.protocols.status_notifier.layout.Node? node
function Menu:get_layout(node_id, depth, names)
    return self._proxy:get_layout(node_id, depth, names or {})
end

---@param on_signal fun(signal: glacier.protocols.status_notifier.host.MenuSignal)
function Menu:signal_stream(on_signal)
    self._proxy:on_layout_updated(function(rev, parent)
        on_signal({
            layout_updated = {
                parent_node = parent,
                revision = rev,
            },
        })
    end)

    self._proxy:on_item_properties_updated(function(updated, removed)
        on_signal({
            properties_updated = {
                updates = updated,
                removal = removed,
            },
        })
    end)
end

--------------
-- Lifetime --
--------------

---@param connection glacier.dbus.Connection
---@param destination string
---@param path string
---@return glacier.protocols.status_notifier.host.Menu?
local function Menu_new(connection, destination, path)
    local proxy = DBusMenuProxy.new(connection, destination, path)

    if not proxy then
        return nil
    end

    return setmetatable({
        _proxy = proxy,
    }, { __index = Menu })
end

---------------
-- Item Impl --
---------------

-------------------
-- Public Method --
-------------------

function Item:bus_id()
    return self._bus_id
end

function Item:proxy()
    return self._proxy
end

---@param connection glacier.dbus.Connection
---@return glacier.protocols.status_notifier.host.Menu?
function Item:menu(connection)
    local menu_path = self._proxy:get_menu()

    if #menu_path == 0 then
        return nil
    end

    return Menu_new(connection, self._destination, menu_path)
end

---@param on_signal fun(signal: glacier.protocols.status_notifier.host.ItemSignal)
function Item:signal_stream(on_signal)
    self._proxy:on_new_title(function()
        on_signal({ new_title = {} })
    end)

    self._proxy:on_new_icon(function()
        on_signal({ new_icon = {} })
    end)

    self._proxy:on_new_attention_icon(function()
        on_signal({ new_attention_icon = {} })
    end)

    self._proxy:on_new_overlay_icon(function()
        on_signal({ new_overlay_icon = {} })
    end)

    self._proxy:on_new_tooltip(function()
        on_signal({ new_tooltip = {} })
    end)

    self._proxy:on_new_menu(function()
        on_signal({ new_menu = {} })
    end)

    self._proxy:on_new_status(function(status)
        on_signal({ new_status = status })
    end)
end

--------------
-- Lifetime --
--------------

---@param connection glacier.dbus.Connection
---@param name string
---@return glacier.protocols.status_notifier.host.Item
local function Item_new(connection, name)
    local destination
    local path = string.gsub(name, "^:[^/]+", function(m)
        destination = m
        return ""
    end)

    if not destination then
        destination = path
        path = _config.items.object
    end

    if path == "" then
        path = _config.items.object
    end

    local proxy = ItemProxy.new(connection, destination, path)

    ---@type glacier.protocols.status_notifier.host.Item
    local item = setmetatable({
        _bus_id = name,
        _destination = destination,
        _proxy = proxy,
    }, { __index = Item })

    return item
end

---------------
-- Host Impl --
---------------

-------------------
-- Public Method --
-------------------

---@param connection glacier.dbus.Connection
---@param name string
---
---@return glacier.protocols.status_notifier.host.Event
local function _build_item(connection, name)
    local item = Item_new(connection, name)
    if not item then
        return {
            error = ("Failed to build item '%s'"):format(name),
        }
    else
        return {
            registered = item,
        }
    end
end

---@param on_event fun(event: glacier.protocols.status_notifier.host.Event)
function Host:item_stream(on_event)
    local connection = self._connection
    self._watcher_proxy:on_item_registered(function(service)
        on_event(_build_item(connection, service))
    end)

    self._watcher_proxy:on_item_unregistered(function(service)
        on_event({
            unregistered = service,
        })
    end)

    local items = self._watcher_proxy:get_registered_items()
    for _, service in ipairs(items) do
        on_event(_build_item(connection, service))
    end
end

--------------
-- Lifetime --
--------------

--local function _build_interface()
--return assert(Interface.builder(_config.host.interface):build())
--end

---@param connection glacier.dbus.Connection
---@param id string
---
---@return glacier.protocols.status_notifier.Host
function Host.new(connection, id)
    local watcher = Watcher.Proxy.new(connection)
    local name = ("%s-%s"):format(_config.host.service_prefix, id)

    local reply = connection:request_name(name)
    if
        reply == Connection.RequestNameReply.already_owner
        or reply == Connection.RequestNameReply.exists
    then
        error("Name already taken")
    end

    local ret = setmetatable({
        _connection = connection,
        _watcher_proxy = watcher,
        _name = name,
    }, Host)

    watcher:register_host(name)

    return ret
end

host.item_status = item_status
host.Host = Host

return host
