local utils = require("glacier.utils")

local sni = require("glacier.protocols.status_notifier")

local _item = require("glacier.services.status_notifier.item")

---@class glacier.services.status_notifier
local status_notifier = {}

local SNI_HOST_ID = "glacier-status-notifier-host"

----------------------
-- Type Definitions --
----------------------

---@enum glacier.services.status_notifier.signal
local _signal = {
    ITEM_ADDED = "glacier::services::status_notifier::item_added",
    ITEM_UPDATED = "glacier::services::status_notifier::item_updated",
    ITEM_REMOVED = "glacier::services::status_notifier::item_removed",

    MENU_LAYOUT_UPDATED = "glacier::services::status_notifier::menu_layout_updated",
    MENU_PROPERTIES_CHANGED = "glacier::services::status_notifier::menu_properties_changed",
}

---@class glacier.services.status_notifier.ItemUpdate
---@field title? string
---@field status? glacier.protocols.status_notifier.host.ItemStatus
---@field icon? snowcap.widget.image.Handle
---@field attention_icon? snowcap.widget.image.Handle
---@field overlay_icon? snowcap.widget.image.Handle

---@class glacier.services.StatusNotifier
---@field package _connection glacier.dbus.Connection
---@field package _host glacier.protocols.status_notifier.host
---@field package _items table<string, glacier.services.status_notifier.Item>
---@field package _signaler snowcap.signal.Signaler
local StatusNotifier = {}

-------------------------
-- StatusNotifier Impl --
-------------------------

---------------------
-- Private Methods --
---------------------

---@package
---@param item_id string
---@param signal glacier.protocols.status_notifier.host.MenuSignal
function StatusNotifier:_on_menu_update(item_id, signal)
    local item = self._items[item_id]
    if not item then
        return
    end

    local menu = item:menu()
    if not menu then
        return
    end

    if signal.layout_updated then
        local parent_node = signal.layout_updated.parent_node
        local updated
        ---@diagnostic disable-next-line:invisible
        menu:_update_layout(parent_node)
        if not updated then
            return
        end

        self._signaler:emit(_signal.MENU_LAYOUT_UPDATED, item_id, parent_node)
    elseif signal.properties_updated then
        --local changeset = menu:_update_properties(signal.properties_updated)

        --if not changeset then
        --return
        --end
        --self._signaler:emit(_signal.MENU_PROPERTIES_CHANGED, item_id, changeset)
    end
end

---@package
---@param item_id string
---@param menu glacier.services.status_notifier.Menu
function StatusNotifier:_on_new_menu(item_id, menu)
    local weak = utils.weak(self)

    ---@diagnostic disable-next-line:invisible
    menu:_update_stream(function(signal)
        local service = weak:get()

        if not service then
            return
        end

        service:_on_menu_update(item_id, signal)
    end)
end

---@package
---@param item_id string
---@param signal glacier.protocols.status_notifier.host.ItemSignal
function StatusNotifier:_on_item_update(item_id, signal)
    local item = self._items[item_id]

    if not item then
        return
    end

    local update = {}

    if signal.new_title then
        ---@diagnostic disable-next-line:invisible
        item:_refresh_title()
        update.title = item:title()
    elseif signal.new_status then
        ---@diagnostic disable-next-line:invisible
        item:_refresh_status(signal.new_status)
        update.status = item:status()
    elseif signal.new_icon then
        ---@diagnostic disable-next-line:invisible
        item:_refresh_icon()
        update.icon = item:icon()
    elseif signal.new_attention_icon then
        ---@diagnostic disable-next-line:invisible
        item:_refresh_attention_icon()
        update.attention_icon = item:attention_icon()
    elseif signal.new_overlay_icon then
        ---@diagnostic disable-next-line:invisible
        item:_refresh_overlay_icon()
        update.overlay_icon = item:overlay_icon()
    elseif signal.new_menu then
        ---@diagnostic disable-next-line:invisible
        item:_refresh_menu(self._connection)
        local menu = item:menu()

        if menu then
            self:_on_new_menu(item_id, menu)

            update.menu = {}
        else
            return
        end
    end

    self._signaler:emit(_signal.ITEM_UPDATED, item_id, update)
end

---@package
---@param remote glacier.protocols.status_notifier.host.Item
function StatusNotifier:_on_item_registered(remote)
    local weak = utils.weak(self)
    ---@diagnostic disable-next-line:invisible
    local item = _item.Item.new(self._connection, remote)
    local unique_id = item:unique_id()

    ---@diagnostic disable-next-line:invisible
    item:_update_stream(function(signal)
        local service = weak:get()

        if not service then
            return
        end

        service:_on_item_update(unique_id, signal)
    end)

    local menu = item:menu()
    if menu then
        self:_on_new_menu(unique_id, menu)
    end

    self._items[item:unique_id()] = item
    self._signaler:emit(_signal.ITEM_ADDED, item:state())
end

--------------------
-- Public Methods --
--------------------

---@return glacier.services.status_notifier.ItemState[]
function StatusNotifier:items()
    local states = {}

    for _, item in pairs(self._items) do
        table.insert(states, item:state())
    end

    return states
end

function StatusNotifier:activate_item(item_id)
    local item = self._items[item_id]

    if not item then
        return
    end

    ---@diagnostic disable-next-line:invisible
    item:_activate()
end

function StatusNotifier:click_menu(item_id, node_id)
    local item = self._items[item_id]
    local menu = item and item:menu()

    if not menu then
        return
    end

    menu:on_click(node_id)
end

function StatusNotifier:hover_menu(item_id, node_id)
    local item = self._items[item_id]
    local menu = item and item:menu()

    if not menu then
        return
    end

    menu:on_hover(node_id)
end

---@param item_id string
---@param node_id integer
---
---@return glacier.services.status_notifier.MenuNode[]?
function StatusNotifier:open_menu(item_id, node_id)
    local item = self._items[item_id]
    local menu = item and item:menu()

    if not menu then
        return
    end

    local update = menu:pre_open(node_id)
    if update then
        ---@diagnostic disable-next-line:invisible
        menu:_update_layout(node_id)
        self._signaler:emit(_signal.MENU_LAYOUT_UPDATED, item_id, node_id)
    end

    return menu:on_open(node_id)
end

---@param name string
---@param callback fun(...): snowcap.signal.HandlerPolicy?
---
---@return snowcap.signal.SignalHandle
function StatusNotifier:connect(name, callback)
    return self._signaler:connect(name, callback)
end

---@param handle snowcap.signal.SignalHandle
function StatusNotifier:disconnect(handle)
    self._signaler:disconnect(handle)
end

-----------
-- Other --
-----------

---@param connection glacier.dbus.Connection
---
---@return glacier.services.StatusNotifier
function StatusNotifier.new(connection)
    local host = sni.Host.new(connection, SNI_HOST_ID)

    ---@type glacier.services.StatusNotifier
    local ret = setmetatable({
        _connection = connection,
        _host = host,
        _items = {},
        _signaler = require("snowcap.signal").Signaler.new(),
    }, { __index = StatusNotifier })

    local weak = utils.weak(ret)
    host:item_stream(function(event)
        local service = weak:get()
        if not service then
            return
        end

        if event.registered then
            service:_on_item_registered(event.registered)
        elseif event.unregistered then
            service._items[event.unregistered] = nil
            service._signaler:emit(_signal.ITEM_REMOVED, event.unregistered)
        end
    end)

    return ret
end

status_notifier.StatusNotifier = StatusNotifier
status_notifier.signal = _signal

return status_notifier
