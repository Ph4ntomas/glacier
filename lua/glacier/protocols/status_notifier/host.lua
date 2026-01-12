local Log = require("snowcap.log")

local Connection = require("glacier.dbus.connection")
local Interface = require("glacier.dbus.object.interface")
local WatcherProxy = require("glacier.protocols.status_notifier.watcher_proxy")
local ItemProxy = require("glacier.protocols.status_notifier.item_proxy")
local DBusMenuProxy = require("glacier.protocols.status_notifier.dbusmenu_proxy")

local _config = require("glacier.protocols.status_notifier.config")

local function build_interface()
    return assert(Interface.builder(_config.host.interface):build())
end

--TODO: Once proxy caching is implemented, this can be removed.

---@class glacier.status_notifier.host.Item
---@field _item_proxy glacier.status_notifier.ItemProxy
---@field _dbus_menu_proxy? glacier.status_notifier.DBusMenuProxy
---@field id string
---@field title string
---@field status string
---@field icon_name string?
---@field icon_theme_path string?
---@field icon_pixmap glacier.status_notifier.PixMap[]?
---@field is_menu boolean
---@field menu_rev? integer
---@field menu_tree? glacier.status_notifier.LayoutNode
local Item = {}
Item.__index = Item
Item.__name = "glacier.status_notifier.host.Item"

---@param connection glacier.dbus.Connection
---@param destination string
---@param path string
---
---@return glacier.status_notifier.host.Item
function Item_new(connection, destination, path)
    local proxy = ItemProxy.new(connection, destination, path)

    local item = setmetatable({ _item_proxy = proxy }, Item)

    item.id = proxy:get_id()
    item.title = proxy:get_title()
    item.status = proxy:get_status()
    item.icon_name = proxy:get_icon_name()
    item.icon_theme_path = proxy:get_icon_theme_path()
    item.is_menu = proxy:is_menu()

    local menu_path = proxy:get_menu()

    if menu_path ~= "" then
        item.is_menu = true

        local menu, err = DBusMenuProxy.new(connection, destination, menu_path)
        if not menu then
            Log.warn(
                ("Could not retrieve menu for %s at path %s: %s"):format(
                    destination,
                    menu_path,
                    err
                )
            )
        end

        item._dbus_menu_proxy = menu
        item._dbus_menu_proxy:on_layout_updated(function(_, _)
            item:_refresh_layout()
        end)

        item:_refresh_layout()
    elseif item.is_menu then
        Log.warn(("%s:is_menu is set, but no menu could be retrieved."):format(destination))
    end
    item.icon_pixmap = proxy:get_icon_pixmap()

    return item
end

--TODO refresh per layout
function Item:_refresh_layout()
    local rev, tree = self._dbus_menu_proxy:get_layout()

    self.menu_rev = rev
    self.menu_tree = tree
end

function Item:hover(node_id)
    self._dbus_menu_proxy:event(node_id, "hovered", 0, 0)
end

function Item:click(node_id)
    self._dbus_menu_proxy:event(node_id, "clicked", 0, 0)
end

--TODO refresh per layout
function Item:about_to_show()
    local node_id = 0

    if self._dbus_menu_proxy then
        if self._dbus_menu_proxy:about_to_show(node_id) then
            self:_refresh_layout()
        end
    end
end

---@class glacier.status_notifier.WeakHost
---@field private _host glacier.status_notifier.Host
local WeakHost = {}
WeakHost.__index = WeakHost
WeakHost.__name = "glacier.status_notifier.WeakHost"

---@param host glacier.status_notifier.Host
---
---@return glacier.status_notifier.WeakHost
function WeakHost.new(host)
    return setmetatable({ _host = host }, WeakHost)
end

---@return glacier.status_notifier.Host?
function WeakHost:upgrade()
    return self._host
end

---@class glacier.status_notifier.Host
---@field _connection glacier.dbus.Connection
---@field _watcher_proxy glacier.status_notifier.WatcherProxy
---@field _items table<string, glacier.status_notifier.host.Item>
---@field _name string
---@field _path string
local Host = {}
Host.__index = Host
Host.__name = "glacier.status_notifier.Host"

function Host.new(connection, id, hooks)
    local watcher_proxy = WatcherProxy.new(connection)
    local name = ("%s-%s"):format(_config.host.service_prefix, id)
    local path = ("%s/$s"):format(_config.host.object_prefix, id)
    local iface = build_interface()

    local interface = connection:router():get_interface(path, _config.host.interface)
    if interface then
        error("Interface is already registered")
    end

    connection:router():interface_at(path, iface)
    local reply = connection:request_name(name)
    if
        reply == Connection.RequestNameReply.already_owner
        or reply == Connection.RequestNameReply.exists
    then
        error("Name already taken")
    end

    local host = setmetatable({
        _connection = connection,
        _watcher_proxy = watcher_proxy,
        _items = {},
        _name = name,
        _path = path,
    }, Host)

    watcher_proxy:register_host(name)

    local weak = WeakHost.new(host)
    watcher_proxy:on_item_registered(function(service)
        local h = weak:upgrade()
        if h then
            h:_on_item_registered(service)
            if hooks.on_register then
                hooks.on_register()
            end
        end
    end)

    watcher_proxy:on_item_unregistered(function(service)
        local h = weak:upgrade()
        if h then
            h:_on_item_unregistered(service)

            if hooks.on_unregister then
                hooks.on_unregister()
            end
        end
    end)

    host:_initialize_item()

    return host
end

function Host:__gc()
    if self._connection and self._name then
        self._connection:release_name(self._name)
    end
end

function Host:_initialize_item()
    local items = self._watcher_proxy:get_registered_items()

    for _, name in ipairs(items) do
        self:_on_item_registered(name)
    end
end

---@param item string
function Host:_on_item_registered(item)
    local destination
    local path = string.gsub(item, "^:[^/]+", function(m)
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

    self._items[item] = Item_new(self._connection, destination, path)
end

function Host:_on_item_unregistered(item)
    self._items[item] = nil
end

function Host:items()
    return self._items
end

return Host
