local _menu = require("glacier.services.status_notifier.menu")

---@class glacier.services.status_notifier.item
local item = {}

----------------------
-- Type Definitions --
----------------------

---@class glacier.services.status_notifier.ItemState
---@field unique_id string
---@field id string
---@field title string
---@field category glacier.protocols.status_notifier.ItemProxy.category
---@field status glacier.protocols.status_notifier.host.ItemStatus
---@field icon snowcap.widget.image.Handle?
---@field attention_icon snowcap.widget.image.Handle?
---@field overlay_icon snowcap.widget.image.Handle?
---@field is_menu boolean

---@class glacier.services.status_notifier.Item
---@field private _state glacier.services.status_notifier.ItemState
---@field private _menu glacier.services.status_notifier.Menu?
---@field private _remote glacier.protocols.status_notifier.host.Item
local Item = {}

---------------
-- Item Impl --
---------------

---------------------
-- Package Methods --
---------------------

---@package
function Item:_refresh_title()
    self._state.title = self._remote:proxy():get_title()
end

---@package
function Item:_refresh_status(new_status)
    self._state.status = new_status
end

---@param pixmap glacier.protocols.status_notifier.PixMap
---@return snowcap.widget.image.Handle
local function pixmap_to_image_handle(pixmap)
    local width = pixmap.x
    local height = pixmap.y

    local rgba = ""

    for i=1, width * height * 4, 4 do
        local a, r, g, b = string.byte(pixmap.data, i, i + 3)

        rgba = rgba .. string.char(r, g, b, a)
    end

    ---@type snowcap.widget.image.Handle
    return {
        rgba = {
            height = height,
            width = width,
            rgba = rgba,
        }
    }
end

---@package
function Item:_refresh_icon()
    local proxy = self._remote:proxy()
    local icon_path = proxy:get_icon_theme_path()
    local name = proxy:get_icon_name()

    local path
    if #icon_path > 0 and #name > 0 then
        path = ("%s/%s.png"):format(icon_path, name)
    end

    if path then
        ---@type snowcap.widget.image.Handle
        self._state.icon = {
            path = path,
        }
        return
    end

    local pixmaps = proxy:get_icon_pixmap()
    local pixmap = pixmaps[1]
    if pixmap then
        self._state.icon = pixmap_to_image_handle(pixmap)
        return
    end

    self._state.icon = nil
end

---@package
function Item:_refresh_attention_icon()
    local proxy = self._remote:proxy()
    local icon_path = proxy:get_icon_theme_path()
    local name = proxy:get_attention_icon_name()

    local path
    if #icon_path > 0 and #name > 0 then
        path = ("%s/%s.png"):format(icon_path, name)
    end

    if path then
        ---@type snowcap.widget.image.Handle
        self._state.attention_icon = {
            path = path,
        }
        return
    end

    local pixmaps = proxy:get_attention_icon_pixmap()
    local pixmap = pixmaps[1]
    if pixmap then
        self._state.attention_icon = pixmap_to_image_handle(pixmap)
        return
    end

    self._state.attention_icon = nil
end

---@package
function Item:_refresh_overlay_icon()
    local proxy = self._remote:proxy()
    local icon_path = proxy:get_icon_theme_path()
    local name = proxy:get_overlay_icon_name()

    local path
    if #icon_path > 0 and #name > 0 then
        path = ("%s/%s.png"):format(icon_path, name)
    end

    if path then
        ---@type snowcap.widget.image.Handle
        self._state.overlay_icon = {
            path = path,
        }
        return
    end

    local pixmaps = proxy:get_overlay_icon_pixmap()
    local pixmap = pixmaps[1]
    if pixmap then
        self._state.overlay_icon = pixmap_to_image_handle(pixmap)
        return
    end

    self._state.overlay_icon = nil
end

---@package
---@param connection glacier.dbus.Connection
function Item:_refresh_menu(connection)
    local remote_menu = self._remote:menu(connection)
    if not remote_menu then
        return
    end

    local menu = _menu.Menu.new(remote_menu)
    self._menu = menu
end

---@package
function Item:_refresh_tooltip() end

---@package
---@param on_event fun(event: glacier.protocols.status_notifier.host.ItemSignal)
function Item:_update_stream(on_event)
    self._remote:signal_stream(function(signal)
        on_event(signal)
    end)
end

---@package
function Item:_activate()
    self._remote:proxy():activate(0, 0)
end

--------------------
-- Public Methods --
--------------------

---@return string
function Item:unique_id()
    return self._state.unique_id
end

function Item:id()
    return self._state.id
end

function Item:category()
    return self._state.category
end

function Item:title()
    return self._state.title
end

function Item:status()
    return self._state.status
end

function Item:icon()
    return self._state.icon
end

function Item:attention_icon()
    return self._state.attention_icon
end

function Item:overlay_icon()
    return self._state.overlay_icon
end

function Item:menu()
    return self._menu
end

function Item:is_menu()
    return self._state.is_menu
end

---@return glacier.services.status_notifier.ItemState
function Item:state()
    return require("snowcap.util").deep_copy(self._state)
end

-------------------
-- Lifetime --
-------------------

---@package
---@param connection glacier.dbus.Connection
---@param remote glacier.protocols.status_notifier.host.Item
---
---@return glacier.services.status_notifier.Item
function Item.new(connection, remote)
    local proxy = remote:proxy()

    local ret = {
        _state = {
            unique_id = remote:bus_id(),
            id = proxy:get_id(),
            title = proxy:get_title(),
            category = proxy:get_category(),
            status = proxy:get_status(),

            is_menu = proxy:is_menu(),
        },

        _remote = remote,
    }

    ret = setmetatable(ret, { __index = Item })

    ret:_refresh_icon()
    ret:_refresh_attention_icon()
    ret:_refresh_overlay_icon()

    ret:_refresh_menu(connection)

    return ret
end

item.Item = Item

return item
