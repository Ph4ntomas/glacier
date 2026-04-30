---@class glacier.services.status_notifier.menu
local menu = {}

---------------------
-- Type Definition --
---------------------

---@class glacier.services.status_notifier.layout.Node
---@field package _id integer
---@field package _parent_id integer
---@field package _properties glacier.protocols.status_notifier.layout.Properties

---@class glacier.services.status_notifier.FlatLayout
---@field _properties glacier.services.status_notifier.layout.Node[]
local FlatLayout = {}

---@class glacier.services.status_notifier.MenuNode
---@field id integer
---@field properties glacier.protocols.status_notifier.layout.Properties

---@class glacier.services.status_notifier.Menu
---@field private _revision integer
---@field private _layout glacier.services.status_notifier.FlatLayout
---@field private _remote glacier.protocols.status_notifier.host.Menu
local Menu = {}

---------------------
-- FlatLayout Impl --
---------------------

---------------------
-- Public function --
---------------------

---@param pnode glacier.protocols.status_notifier.layout.Node
function FlatLayout:update_layout(pnode)
    local node_id = pnode:id()
    if node_id == 0 then
        local new_layout = FlatLayout.build(pnode)

        self._properties = new_layout._properties

        return
    end

    local idx
    for i, node in ipairs(self._properties) do
        if node._id == node_id then
            idx = i
            break
        end
    end
    table.remove(self._properties, idx)

    local parent_to_remove = { node_id }
    while #parent_to_remove > 0 do
        local parent_id = table.remove(parent_to_remove)
        local to_remove = {}

        for i, node in ipairs(self._properties) do
            if node._parent_id == parent_id then
                table.insert(to_remove, i)
            end
        end

        for _, i in ipairs(to_remove) do
            local node = table.remove(self._properties, i)
            table.insert(parent_to_remove, node._id)
        end
    end

    local new_layout = FlatLayout.build(pnode)
    table.move(
        new_layout._properties,
        1,
        #new_layout._properties,
        #self._properties + 1,
        self._properties
    )
end

--function FlatLayout:update_properties(updates, removal)

--end

--------------
-- Lifetime --
--------------

---@param pnode glacier.protocols.status_notifier.layout.Node
---
---@return glacier.services.status_notifier.FlatLayout
function FlatLayout.build(pnode)
    local properties = {}

    local node_id = pnode:id()
    ---@type glacier.services.status_notifier.layout.Node
    local node = {
        _id = node_id,
        _parent_id = node_id,
        _properties = pnode:properties(),
    }

    table.insert(properties, node)

    for _, child in ipairs(pnode:children()) do
        local child_id = child:id()
        local child_node = FlatLayout.build(child)

        local child_props = child_node._properties

        for _, n in ipairs(child_props) do
            if n._id == child_id then
                n._parent_id = node_id
                break
            end
        end

        table.move(child_props, 1, #child_props, #properties + 1, properties)
    end

    return { _properties = properties }
end

---@param pnode glacier.protocols.status_notifier.layout.Node
---
---@return glacier.services.status_notifier.FlatLayout
function FlatLayout.new(pnode)
    local ret = FlatLayout.build(pnode)

    return setmetatable(ret, { __index = FlatLayout })
end

---------------
-- Menu Impl --
---------------

--------------------
-- PackageMethods --
--------------------

---@package
function Menu:_update_stream(on_event)
    self._remote:signal_stream(on_event)
end

---@package
---Update the menu layout
---
---@param parent_node integer
---@return boolean Updated Whether the layout was updated
function Menu:_update_layout(parent_node)
    local rev, node = self._remote:get_layout(parent_node, -1, {})

    if not rev or not node then
        return false
    end

    if self._revision > rev then
        return false
    end

    self._layout:update_layout(node)
    self._revision = rev

    return true
end

---@package
---@param properties_update glacier.protocols.status_notifier.host.menu_signal.PropertiesUpdated
function Menu:_update_properties(properties_update)
    local _ = properties_update
    return nil
end

--------------------
-- Public Methods --
--------------------

function Menu:on_click(node_id)
    self._remote:proxy():event(node_id, "clicked", 0, 0)
end

function Menu:on_hover(node_id)
    self._remote:proxy():event(node_id, "hovered", 0, 0)
end

function Menu:pre_open(node_id)
    return self._remote:proxy():about_to_show(node_id)
end

---@param parent_id integer
---@return glacier.services.status_notifier.MenuNode[]?
function Menu:on_open(parent_id)
    local children = {}

    for _, node in ipairs(self._layout._properties) do
        if node._parent_id == parent_id and node._id ~= parent_id then
            local child = {
                id = node._id,
                properties = node._properties,
            }

            table.insert(children, child)
        end
    end

    if #children == 0 then
        return nil
    end
    return children
end

--------------
-- Lifetime --
--------------

---@param remote glacier.protocols.status_notifier.host.Menu
---
---@return glacier.services.status_notifier.Menu?
function Menu.new(remote)
    local revision, node = remote:get_layout(0, -1, {})

    if not revision or not node then
        return nil
    end

    local layout = FlatLayout.new(node)

    ---@type glacier.services.status_notifier.Menu
    local ret = {
        _revision = revision,
        _layout = layout,
        _remote = remote,
    }

    return setmetatable(ret, { __index = Menu })
end

menu.Menu = Menu
return menu
