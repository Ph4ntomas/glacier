local Widget = require("snowcap.widget")

local _base = require("snowcap.widget.base")

local _menu = require("glacier.menu")
local color = require("glacier.misc.color")
local icons = require("glacier.misc.icons")

---@class glacier.widget.systray.menu
local menu = {}

---------------------
-- Type definition --
---------------------

---@class glacier.widget.systray.menu.Common
---@field item_id string
---@field node_id integer
---@field label string
---
---@field service glacier.services.StatusNotifier

---@class glacier.widget.systray.menu.Kind
---@field label? {}
---@field radio? boolean
---@field checkmark? boolean

---@class glacier.widget.systray.menu.Entry: glacier.widget.systray.menu.Common, snowcap.widget.Program
---@field kind glacier.widget.systray.menu.Kind
local Entry = setmetatable({}, { __index = _base.Base })

---@class glacier.widget.systray.menu.SubMenu: glacier.widget.systray.menu.Common, glacier.menu.entry.WithMenu
---@field config glacier.menu.PopupConfig
local SubMenu = setmetatable({}, { __index = _base.Base })

----------------------
-- Modules function --
----------------------

---@param sni_entries glacier.services.status_notifier.MenuNode[]
---@param service glacier.services.StatusNotifier
---@param item_id string
---@param config glacier.menu.PopupConfig
---@return glacier.menu.Menu
function menu.make_menu(sni_entries, service, item_id, config)
    local prev_is_sep = true
    local entries = {}

    for _, node in ipairs(sni_entries) do
        if not node.properties.visible then
            goto continue
        elseif node.properties.type == "separator" then
            if not prev_is_sep then
                table.insert(entries, _menu.entry.separator())
            end

            prev_is_sep = true
            goto continue
        end

        prev_is_sep = false

        if node.properties["children-display"] == "submenu" then
            local submenu = SubMenu.new(service, item_id, node.id, node.properties, config)
            local entry = _menu.entry.menu(submenu, {
                disabled = not node.properties.enabled,
            })
            table.insert(entries, entry)
        else
            local _entry = Entry.new(service, item_id, node.id, node.properties)
            local entry = _menu.entry.standard(_entry, {
                disabled = not node.properties.enabled,
            })
            table.insert(entries, entry)
        end

        ::continue::
    end

    return _menu({
        entries = entries,
    })
end

----------------
-- Entry Impl --
----------------

---------------------------------
-- impl snowcap.widget.Program --
---------------------------------

---Creates a widget definition for display by Snowcap.
---
---A widget may return nil to notify its parent program that it has
---nothing to display. It's up to the parent to decide whether to display a
---placeholder or to remove the widget from the tree.
---
---@return snowcap.widget.WidgetDef?
function Entry:view()
    local children = {
        Widget.text({
            text = self.label,
            width = Widget.length.Fill,
        }),
    }

    local toggle_icon
    if self.kind.checkmark ~= nil then
        toggle_icon = self.kind.checkmark ~= nil and icons.checkbox.select(self.kind.checkmark)
    elseif self.kind.radio ~= nil then
        toggle_icon = self.kind.radio ~= nil and icons.radio.select(self.kind.radio)
    end

    if toggle_icon then
        local handle = toggle_icon:to_image_handle(color.from_hex("#FFFFFF"))
        local icon = Widget.Image({
            handle = handle,
            content_fit = Widget.image.content_fit.SCALE_DOWN,
            height = Widget.length.Fixed(16.),
            width = Widget.length.Fixed(16.),
        })

        table.insert(children, icon)
    end

    return Widget.row({
        children = children,
    })
end

---Updates this widget program with the received message.
---@param msg any|glacier.menu.entry.Message
function Entry:update(msg)
    if msg.tag ~= _menu.entry.MESSAGE_TAG then
        return
    end

    local event = msg.event
    if not event then
        return
    end

    if event.hover then
        self.service:hover_menu(self.item_id, self.node_id)
    elseif event.submit then
        self.service:click_menu(self.item_id, self.node_id)
    end
end

---Called when a surface has been created with this program.
---
---A surface handle is provided to allow the program to manupulate
---the surface. This handle should be passed to any child programs
---to allow them to use it as well.
---
---@param _ snowcap.widget.SurfaceEvent
function Entry:event(_) end

--------------
-- Lifetime --
--------------

---@param service glacier.services.StatusNotifier
---@param item_id string
---@param node_id integer
---@param properties glacier.protocols.status_notifier.layout.Properties
---
---@return glacier.widget.systray.menu.Entry
function Entry.new(service, item_id, node_id, properties)
    local base = _base.Base.new()
    local ret = setmetatable(base, { __index = Entry }) --[[@as glacier.widget.systray.menu.Entry]]

    ret.service = service
    ret.item_id = item_id
    ret.node_id = node_id
    ret.label = properties.label

    if properties["toggle-type"] == "radio" then
        ret.kind = {
            radio = properties["toggle-state"] == 1,
        }
    elseif properties["toggle-type"] == "checkmark" then
        ret.kind = {
            checkmark = properties["toggle-state"] == 1,
        }
    else
        ret.kind = {
            label = {},
        }
    end

    return ret
end

------------------
-- SubMenu Impl --
------------------

---------------------------------
-- impl snowcap.widget.Program --
---------------------------------

---Creates a widget definition for display by Snowcap.
---
---A widget may return nil to notify its parent program that it has
---nothing to display. It's up to the parent to decide whether to display a
---placeholder or to remove the widget from the tree.
---
---@return snowcap.widget.WidgetDef?
function SubMenu:view()
    return Widget.text({
        text = self.label,
    })
end

---Updates this widget program with the received message.
---@param msg any|glacier.menu.entry.Message
function SubMenu:update(msg)
    if msg.tag ~= _menu.entry.MESSAGE_TAG then
        return
    end

    local event = msg.event
    if not event then
        return
    end

    if event.hover then
        self.service:hover_menu(self.item_id, self.node_id)
    end
end

---Called when a surface has been created with this program.
---
---A surface handle is provided to allow the program to manupulate
---the surface. This handle should be passed to any child programs
---to allow them to use it as well.
---
---@param _ snowcap.widget.SurfaceEvent
function SubMenu:event(_) end

--- Called by glacier.menu.Entry to retrieve the menu.
function SubMenu:open_menu()
    local service = self.service
    local item_id = self.item_id
    local node_id = self.node_id

    local nodes = service:open_menu(item_id, node_id)
    if nodes then
        return menu.make_menu(nodes, service, item_id, self.config)
    end
end

--------------
-- Lifetime --
--------------

---@param service glacier.services.StatusNotifier
---@param item_id string
---@param node_id integer
---@param properties glacier.protocols.status_notifier.layout.Properties
---@param config glacier.menu.PopupConfig
function SubMenu.new(service, item_id, node_id, properties, config)
    local base = _base.Base.new()
    local ret = setmetatable(base, { __index = SubMenu }) --[[@as glacier.widget.systray.menu.SubMenu]]

    ret.service = service
    ret.item_id = item_id
    ret.node_id = node_id
    ret.label = properties.label
    ret.config = config

    return ret
end

-----------
-- Other --
-----------

return menu
