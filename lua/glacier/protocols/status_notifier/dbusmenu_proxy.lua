local Log = require("snowcap.log")

local Proxy = require("glacier.dbus.proxy")
local Types = require("glacier.dbus.type")

local _config = require("glacier.protocols.status_notifier.config")

---@enum glacier.status_notifier.DBusMenuProxy.status
local status = {
    normal = "normal",
    notice = "notice",
    unknown = "",
}

---@enum glacier.status_notifier.LayoutNode.event
local event = {
    clicked = "clicked",
    hovered = "hovered",
}

---@class glacier.status_notifier.LayoutNode.Properties
---@field type string Either "standard", "separator", or x-<vendor>-<custom type>.
---@field label string Text of the Item.
---@field enabled boolean Whether the item can be activated or not.
---@field visible boolean True if the item is visible in the menu.
---@field icon-name string Icon name of the item, following the freedesktop.org icon spec.
---@field icon-data string? PNG data of the icon.
---@field shortcut string[][] The shortcut of the item. Each array represents the key press in the list of keypresses.
---@field toggle-type string One of: "checkmark", "radio", or an empty string if the item cannot be toggled.
---@field toggle-state integer Current state of a togglable item.
---@field children-display string If the item has children, the property is set to "submenu"

local function Properties_from_dict(dict)
    local props = {}
    for k, v in pairs(dict:get()) do
        ---@cast k string
        ---@cast v glacier.dbus.type.Variant

        local inner = v:get()
        if not inner:is_container() then
            props[k] = inner:get()
        else
            Log.warn(("Not handling: %s. Container are not supported yet."):format(k))
        end
    end

    return props
end

---@class glacier.status_notifier.LayoutNode
---@field _id integer
---@field _props glacier.status_notifier.LayoutNode.Properties
---@field _children glacier.status_notifier.LayoutNode[]
local LayoutNode = {}
LayoutNode.status = status
LayoutNode.event = event
LayoutNode.__index = LayoutNode
LayoutNode.__name = "glacier.status_notifier.LayoutNode"

---@param id integer
---@param properties glacier.status_notifier.LayoutNode.Properties
---@param children? glacier.status_notifier.LayoutNode[]
---
---@return glacier.status_notifier.LayoutNode
local function LayoutNode_new(id, properties, children)
    local default_props = {
        ["type"] = "standard",
        ["label"] = "",
        ["enabled"] = true,
        ["visible"] = true,
        ["icon-name"] = "",
        ["icon-data"] = nil,
        ["shortcut"] = {},
        ["toggle-type"] = "",
        ["toggle-state"] = -1,
        ["children-display"] = "",
    }

    properties = require("glacier.utils").merge_table(default_props, properties)

    children = children or {}

    return setmetatable({
        _id = id,
        _props = properties,
        _children = children,
    }, LayoutNode)
end

---@param layout glacier.dbus.type.Struct
local function LayoutNode_from_struct(layout)
    local dbus_id = layout[1] --[[@as glacier.dbus.type.Int32]]
    local dbus_props = layout[2] --[[@as glacier.dbus.type.Dict]]
    local dbus_children = layout[3] --[[@as glacier.dbus.type.Array]]

    local id = dbus_id:get()
    local props = Properties_from_dict(dbus_props)

    local children = {}
    for _, child in ipairs(dbus_children:get()) do
        ---@cast child glacier.dbus.type.Variant
        local child_layout = LayoutNode_from_struct(child:get() --[[@as glacier.dbus.type.Struct]])
        table.insert(children, child_layout)
    end

    return LayoutNode_new(id, props, children)
end

function LayoutNode:id()
    return self._id
end

function LayoutNode:label()
    return self._props.label
end

function LayoutNode:is_submenu()
    return self._props["children-display"] == "submenu"
end

function LayoutNode:is_separator()
    return self._props.type == "separator"
end

function LayoutNode:is_standard()
    return self._props.type == "standard"
end

function LayoutNode:is_radio()
    return self._props["toggle-type"] == "radio"
end

function LayoutNode:is_checkbox()
    return self._props["toggle-type"] == "checkmark"
end

function LayoutNode:is_toggled()
    return self._props["toggle-state"] == 1
end

function LayoutNode:is_enabled()
    return self._props.enabled
end

function LayoutNode:is_visible()
    return self._props.visible
end

function LayoutNode:children()
    return self._children or {}
end

---@class glacier.status_notifier.DBusMenuProxy
---@field private _proxy glacier.dbus.Proxy
local DBusMenuProxy = {}
DBusMenuProxy.status = status
DBusMenuProxy.__index = DBusMenuProxy
DBusMenuProxy.__name = "glacier.status_notifier.DBusMenuProxy"

function DBusMenuProxy.new(connection, service, path)
    local proxy, err = Proxy.builder(connection)
        :with_destination(service)
        :with_path(path)
        :with_interface(_config.dbusmenu.interface)
        :build()

    if not proxy then
        return nil, err
    end

    return setmetatable({ _proxy = proxy }, DBusMenuProxy)
end

------------------
-- Methods      --
------------------

---@param parent_id integer? Id of the node to retrieve. nil or 0 gets the root node.
---@param max_depth integer? Maximum level of recursion in the layout. Defaults to -1 (no limit).
---@param properties string[]? List of properties to retrieve.
---
---@return integer? revision
---@return glacier.status_notifier.LayoutNode?
function DBusMenuProxy:get_layout(parent_id, max_depth, properties)
    parent_id = parent_id or 0
    max_depth = max_depth or -1
    properties = properties or {}

    local dbus_properties = {}
    for _, p in ipairs(properties) do
        table.insert(dbus_properties, Types.String(p))
    end

    if #dbus_properties == 0 then
        dbus_properties = Types.String
    end

    local args = Types.Struct({
        Types.Int32(parent_id),
        Types.Int32(max_depth),
        Types.Array(dbus_properties),
    })

    local ret = self._proxy:call("GetLayout", args)

    if ret:is_error() then
        local err = ret:error()
        Log.debug(("Could not get layout: %s"):format(err))
        return nil, nil
    end

    local body = ret:ok()
    local dbus_revision = body[1] --[[@as glacier.dbus.type.UInt32]]
    local dbus_layout = body[2] --[[@as glacier.dbus.type.Struct]]

    local layout = LayoutNode_from_struct(dbus_layout)

    return dbus_revision:get(), layout
end

---@param ids integer[]? Ids of the node to retrieve. If nil or empty, fetch from all items.
---@param properties string[]? List of properties to retrieve.
---
---@return { id:integer, props: glacier.status_notifier.LayoutNode.Properties }[]?
function DBusMenuProxy:get_group_properties(ids, properties)
    ids = ids or {}
    properties = properties or {}
    local _ = ids
    _ = properties

    Log.error("DBusMenuProxy:get_group_properties is unimplemented.")

    return {}
end

---@param node_id integer
---@param property_name string
---
---@return any?
function DBusMenuProxy:get_property(node_id, property_name)
    local _ = node_id
    _ = property_name

    Log.error("DBusMenuProxy:get_property is not implemented.")

    return nil
end

---@param node_id integer
---@param evt glacier.status_notifier.LayoutNode.event
---@param _data any
---@param timestamp integer
function DBusMenuProxy:event(node_id, evt, _data, timestamp)
    local _ = _data
    timestamp = timestamp >= 0 and timestamp or 0

    local args = Types.Struct({
        Types.Int32(node_id),
        Types.String(evt),
        Types.Variant(Types.Int32(0)),
        Types.UInt32(timestamp),
    })

    local ret = self._proxy:call("Event", args)

    if ret:is_error() then
        local err = ret:error() --[[@as glacier.dbus.message.CallError]]
        Log.warn(("Error calling DBusMenu:Event(): %s"):format(err))
    end
end

---@param node_id integer
---
---@return boolean # Whether the event should result in the menu being updated.
function DBusMenuProxy:about_to_show(node_id)
    local args = Types.Struct({
        Types.Int32(node_id),
    })

    local ret = self._proxy:call("AboutToShow", args)

    if ret:is_error() then
        local err = ret:error() --[[@as glacier.dbus.message.CallError]]
        Log.warn(("Error calling DBusMenu:Event(): %s"):format(err))
        return false
    end

    local body = ret:ok()
    local v = body[1] --[[@as glacier.dbus.type.Boolean]]

    return v:get()
end

------------------
-- Properties   --
------------------

---@return integer?
function DBusMenuProxy:get_version()
    local value, err = self._proxy:get_property("Version")

    if not value then
        Log.debug(("Could not retrieve Version: %s"):format(err))
        return nil
    end

    ---@cast value glacier.dbus.type.UInt32
    return value:get()
end

---@return glacier.status_notifier.DBusMenuProxy.status
function DBusMenuProxy:get_status()
    local value, err = self._proxy:get_property("Status")

    if not value then
        Log.debug(("Could not retrieve Status: %s"):format(err))
        return status.unknown
    end

    ---@cast value glacier.dbus.type.String
    return value:get()
end

------------------
-- Signals      --
------------------

---@alias glacier.status_notifier.ItemsPropertiesUpdatedHandler
---| fun(updated: table<integer, glacier.status_notifier.LayoutNode.Properties>, removed: table<integer, string[]>)

---@param f glacier.status_notifier.ItemsPropertiesUpdatedHandler
function DBusMenuProxy:on_item_properties_updated(f)
    self._proxy:on_signal("ItemsPropertiesUpdated", function(_, _, body)
        local raw_updated = body[1] --[[@as glacier.dbus.type.Array]]
        local raw_removed = body[2] --[[@as glacier.dbus.type.Array]]

        local updated = {}
        for _, v in ipairs(raw_updated:get()) do
            ---@cast v glacier.dbus.type.Struct
            local idx = v[1] --[[@as glacier.dbus.type.Int32]]
            local dict = v[2] --[[@as glacier.dbus.type.Dict]]

            local props = Properties_from_dict(dict)
            updated[idx:get()] = props
        end

        local removed = {}
        for _, v in ipairs(raw_removed:get()) do
            ---@cast v glacier.dbus.type.Struct
            local idx = v[1] --[[@as glacier.dbus.type.Int32]]
            local rm_arr = v[2] --[[@as glacier.dbus.type.Array]]

            local list = {}
            for _, pname in ipairs(rm_arr:get()) do
                ---@cast pname glacier.dbus.type.String
                table.insert(list, pname:get())
            end

            removed[idx:get()] = list
        end

        f(updated, removed)
    end)
end

---@alias glacier.status_notifier.LayoutUpdateHandler fun(revision:integer, parent_id:integer)

---@param f glacier.status_notifier.LayoutUpdateHandler
function DBusMenuProxy:on_layout_updated(f)
    self._proxy:on_signal("LayoutUpdated", function(_, _, body)
        local rev = body[1] --[[@as glacier.dbus.type.UInt32]]
        local parent_id = body[2] --[[@as glacier.dbus.type.Int32]]

        f(rev:get(), parent_id:get())
    end)
end

---@alias glacier.status_notifier.ItemActivationRequestHandler fun(id:integer, timestamp: integer)

---@param f glacier.status_notifier.ItemActivationRequestHandler
function DBusMenuProxy:on_item_activation_requested(f)
    self._proxy:on_signal("ItemActivationRequested", function(_, _, body)
        local id = body[1] --[[@as glacier.dbus.type.Int32]]
        local timestamp = body[2] --[[@as glacier.dbus.type.UInt32]]

        f(id:get(), timestamp:get())
    end)
end

return DBusMenuProxy
