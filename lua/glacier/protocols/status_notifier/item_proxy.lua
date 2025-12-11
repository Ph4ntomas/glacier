local Log = require("snowcap.log")

local Proxy = require("glacier.dbus.proxy")
local Types = require("glacier.dbus.type")

local _config = require("glacier.protocols.status_notifier.config")

---@enum glacier.status_notifier.ItemProxy.scroll_orientation
local scroll_orientation = {
    horizontal = "horizontal",
    vertical = "vertical",
}

---@enum glacier.status_notifier.ItemProxy.category
local category = {
    ApplicationStatus = "ApplicationStatus",
    Communications = "Communications",
    SystemServices = "SystemServices",
    Hardware = "Hardware",
    Unknown = "",
}

---@enum glacier.status_notifier.ItemProxy.status
local status = {
    Passive = "Passive",
    Active = "Active",
    NeedsAttention = "NeedsAttention",
}

---@class glacier.status_notifier.PixMap
---@field x integer
---@field y integer
---@field data string
local PixMap = {}
PixMap.__index = PixMap
PixMap.__name = "glacier.status_notifier.PixMap"

---@param map glacier.dbus.type.Struct
function Pixmap_from_dbus(map)
    local x = map[1]:get()
    local y = map[2]:get()
    local arr = map[3] --[[@as glacier.dbus.type.Array]]

    local data = {}
    for _, v in ipairs(arr:get()) do
        ---@cast v glacier.dbus.type.Byte
        table.insert(data, string.char(v:get()))
    end

    return setmetatable({ x = x, y = y, data = table.concat(data) }, PixMap)
end

---@class glacier.status_notifier.ItemProxy
---@field private _proxy glacier.dbus.Proxy
local ItemProxy = {}
ItemProxy.scroll_orientation = scroll_orientation
ItemProxy.category = category
ItemProxy.status = status
ItemProxy.__index = ItemProxy
ItemProxy.__name = "glacier.status_notifier.ItemProxy"

---@param connection glacier.dbus.Connection
---@param service string
---@param path? string
---
---@return glacier.status_notifier.ItemProxy
function ItemProxy.new(connection, service, path)
    local proxy = Proxy.builder(connection)
        :with_destination(service)
        :with_path(path or _config.items.object)
        :with_interface(_config.items.interface)
        :build()

    return setmetatable({ _proxy = proxy }, ItemProxy)
end

------------------
-- Methods      --
------------------

---@param x integer
---@param y integer
function ItemProxy:context_menu(x, y)
    self._proxy:call(
        "ContextMenu",
        Types.Struct({
            Types.Int32(x),
            Types.Int32(y),
        })
    )
end

---@param x integer
---@param y integer
function ItemProxy:activate(x, y)
    self._proxy:call(
        "Activate",
        Types.Struct({
            Types.Int32(x),
            Types.Int32(y),
        })
    )
end

---@param x integer
---@param y integer
function ItemProxy:secondary_activate(x, y)
    self._proxy:call(
        "SecondaryActivate",
        Types.Struct({
            Types.Int32(x),
            Types.Int32(y),
        })
    )
end

---@param delta integer
---@param orientation glacier.status_notifier.ItemProxy.scroll_orientation
function ItemProxy:scroll(delta, orientation)
    self._proxy:call(
        "Scroll",
        Types.Struct({
            Types.Int32(delta),
            Types.String(orientation),
        })
    )
end

---@param token string
function ItemProxy:provide_xdg_activation_token(token)
    local _ = token
    Log.error("provide_xdg_activation is unimplemented.")
end

------------------
-- Properties   --
------------------

---@return glacier.status_notifier.ItemProxy.category
function ItemProxy:get_category()
    local value, err = self._proxy:get_property("Category")

    if not value then
        Log.debug(("Could not retrieve Category: %s"):format(tostring(err)))
        return category.Unknown
    end

    ---@cast value glacier.dbus.type.String
    return value:get()
end

---@return string
function ItemProxy:get_id()
    local value, err = self._proxy:get_property("Id")

    if not value then
        Log.debug(("Could not retrieve Id: %s"):format(tostring(err)))
        return ""
    end

    ---@cast value glacier.dbus.type.String
    return value:get()
end

---@return string
function ItemProxy:get_title()
    local value, err = assert(self._proxy:get_property("Title"))

    if not value then
        Log.debug(("Could not retrieve Title: %s"):format(tostring(err)))
        return ""
    end

    ---@cast value glacier.dbus.type.String
    return value:get()
end

---@return glacier.status_notifier.ItemProxy.status
function ItemProxy:get_status()
    local value, err = self._proxy:get_property("Status")

    if not value then
        Log.debug(("Could not retrieve Status: %s"):format(tostring(err)))
        return status.Passive
    end

    ---@cast value glacier.dbus.type.String
    return value:get()
end

-- There are discrepancies between FDO SNI and KDE's implementation.
--function ItemProxy:get_window_id()
--end

---@return string
function ItemProxy:get_icon_theme_path()
    local value, err = self._proxy:get_property("IconThemePath")

    if not value then
        Log.debug(("Could not retrieve icon_theme_path: %s"):format(tostring(err)))
        return ""
    end

    ---@cast value glacier.dbus.type.String
    return value:get()
end

---@return string
function ItemProxy:get_menu()
    local value, err = self._proxy:get_property("Menu")

    if not value then
        Log.debug(("Could not retrieve Menu path: %s"):format(tostring(err)))
        return ""
    end

    ---@cast value glacier.dbus.type.ObjectPath
    return value:get()
end

---@return boolean
function ItemProxy:is_menu()
    local value, err = self._proxy:get_property("ItemIsMenu")

    if not value then
        Log.debug(("Could not retrieve ItemIsMenu: %s"):format(tostring(err)))
        return false
    end

    ---@cast value glacier.dbus.type.Boolean
    return value:get()
end

---@return string
function ItemProxy:get_icon_name()
    local value, err = self._proxy:get_property("IconName")

    if not value then
        Log.debug(("Could not retrieve IconName: %s"):format(tostring(err)))
        return ""
    end

    ---@cast value glacier.dbus.type.String
    return value:get()
end

---@return glacier.status_notifier.PixMap[]
function ItemProxy:get_icon_pixmap()
    local array, err = self._proxy:get_property("IconPixmap")

    if not array then
        Log.debug(("Could not retrieve IconPixmap: %s"):format(tostring(err)))
        return {}
    end

    ---@cast array glacier.dbus.type.Array
    ---@type glacier.status_notifier.PixMap[]
    local ret = {}

    for _, pm in ipairs(array:get()) do
        ---@cast pm glacier.dbus.type.Struct
        table.insert(ret, Pixmap_from_dbus(pm))
    end

    return ret
end

---@return string
function ItemProxy:get_overlay_icon_name()
    local value, err = self._proxy:get_property("OverlayIconName")

    if not value then
        Log.debug(("Could not retrieve OverlayIconName: %s"):format(tostring(err)))
        return ""
    end

    ---@cast value glacier.dbus.type.String
    return value:get()
end

---@return glacier.status_notifier.PixMap[]
function ItemProxy:get_overlay_icon_pixmap()
    local array, err = self._proxy:get_property("OverlayIconPixmap")

    if not array then
        Log.debug(("Could not retrieve OverlayIconPixmap: %s"):format(tostring(err)))
        return {}
    end

    ---@cast array glacier.dbus.type.Array
    ---@type glacier.status_notifier.PixMap[]
    local ret = {}

    for _, pm in ipairs(array:get()) do
        ---@cast pm glacier.dbus.type.Struct
        table.insert(ret, Pixmap_from_dbus(pm))
    end

    return ret
end

---@return string
function ItemProxy:get_attention_icon_name()
    local value, err = self._proxy:get_property("AttentionIconName")

    if not value then
        Log.debug(("Could not retrieve AttentionIconName: %s"):format(tostring(err)))
        return ""
    end

    ---@cast value glacier.dbus.type.String
    return value:get()
end

---@return glacier.status_notifier.PixMap[]
function ItemProxy:get_attention_icon_pixmap()
    local array, err = self._proxy:get_property("AttentionIconPixmap")

    if not array then
        Log.debug(("Could not retrieve OverlayIconPixmap: %s"):format(tostring(err)))
        return {}
    end

    ---@cast array glacier.dbus.type.Array
    ---@type glacier.status_notifier.PixMap[]
    local ret = {}

    for _, pm in ipairs(array:get()) do
        ---@cast pm glacier.dbus.type.Struct
        table.insert(ret, Pixmap_from_dbus(pm))
    end

    return ret
end

---@return string
function ItemProxy:get_attention_movie_name()
    local value, err = self._proxy:get_property("AttentionMovieName")

    if not value then
        Log.debug(("Could not retrieve AttentionMovieName: %s"):format(tostring(err)))
        return ""
    end

    ---@cast value glacier.dbus.type.String
    return value:get()
end

------------------
-- Signals      --
------------------

---@param f fun()
function ItemProxy:on_new_title(f)
    self._proxy:on_signal("NewTitle", function(_, _)
        f()
    end)
end

---@param f fun()
function ItemProxy:on_new_icon(f)
    self._proxy:on_signal("NewIcon", function(_, _)
        f()
    end)
end

---@param f fun()
function ItemProxy:on_new_attention_icon(f)
    self._proxy:on_signal("NewAttentionIcon", function(_, _)
        f()
    end)
end

---@param f fun()
function ItemProxy:on_new_overlay_icon(f)
    self._proxy:on_signal("NewOverlayIcon", function(_, _)
        f()
    end)
end

---@param f fun()
function ItemProxy:on_new_menu(f)
    self._proxy:on_signal("NewMenu", function(_, _)
        f()
    end)
end

---@param f fun()
function ItemProxy:on_new_tooltip(f)
    self._proxy:on_signal("NewToolTip", function(_, _)
        f()
    end)
end

---@param f fun(string)
function ItemProxy:on_new_status(f)
    self._proxy:on_signal("Status", function(_, body)
        f(body[1]:get())
    end)
end

return ItemProxy
