local Log = require("pinnacle.log") ---@diagnostic disable-line:unused-local
local signal = require("glacier.widget.signal")

local Widget = require("snowcap.widget")

local Base = require("glacier.widget.base")
local widget_signal = require("glacier.widget.signal")
local dbus = require("glacier.misc.dbus")

local SNIHost = require("glacier.protocols.status_notifier.host")

local Popup = require("snowcap.popup")
local Menu = require("glacier.menu")

---@class glacier.widget.systray
---@field mt metatable This module metatable
local systray = { mt = {} }

---@lcat nodoc
---@package
---
---Private segment of the systray module
---@class glacier.widget._systray
local _systray = {}

---@class glacier.widget.systray.MenuEntry: glacier.menu.entry.EntryBase
---@field private _item glacier.status_notifier.host.Item
---@field private _node glacier.status_notifier.LayoutNode
---@field private _menu_config glacier.menu.Config
local MenuEntry = Menu.entry.EntryBase:new_type()
MenuEntry.__index = MenuEntry
MenuEntry.__name = "glacier.widget.systray.MenuEntry"

function MenuEntry:label()
    return self._node:label()
end

function MenuEntry:disabled()
    return not self._node:is_enabled()
end

function MenuEntry:activate(hover)
    self._item:hover(self._node:id())

    if hover and self._node:is_submenu() then
        return Menu.action.entry.OpenMenu()
    end
end

function MenuEntry:submit()
    if self._node:is_submenu() then
        return Menu.action.entry.OpenMenu()
    else
        self._item:click(self._node:id())
        return Menu.action.menu.Close()
    end
end

function MenuEntry:open_menu()
    if not self._node:is_submenu() then
        return nil
    end

    local entries = {}
    local prev_is_sep = true
    local children = self._node:children()

    for _, node in ipairs(children) do
        if not node:is_visible() then
            goto continue
        end

        if node:is_separator() then
            if prev_is_sep then
                goto continue
            end

            table.insert(entries, Menu.entry.separator())
            prev_is_sep = true
        elseif node:is_standard() then
            prev_is_sep = false

            local menu_config = require("snowcap.util").deep_copy(self._menu_config)
            table.insert(entries, MenuEntry.new(self._item, node, menu_config))
        end

        ::continue::
    end

    -- We don't want to have the entries in the main config here
    local menu_config = require("snowcap.util").deep_copy(self._menu_config)
    menu_config.entries = entries
    return Menu.Menu:new(menu_config)
end

---@param active boolean
---@param style glacier.menu.entry.Style
---@param icon_mask glacier.image.AlphaMask
---@return snowcap.widget.WidgetDef
function MenuEntry:view_toggle(active, style, icon_mask)
    local state = Menu.entry.get_state(self, active)
    local entry_style = Menu.entry.entry_style_for_state(style, state)

    local label_widget = Widget.text({
        text = self:label(),
        width = Widget.length.Fill,
        style = {
            color = entry_style.fg_color,
            font = style.font,
            pixels = style.font_size,
        },
    })

    local icon_handle =
        icon_mask:to_image_handle(style.menu_indicator.color or entry_style.fg_color)
    local menu_icon = Widget.Image({
        handle = icon_handle,
        content_fit = Widget.image.content_fit.SCALE_DOWN,
        height = Widget.length.Fixed(16),
        width = Widget.length.Fixed(16),
    })

    return Widget.container({
        child = Widget.row({
            children = {
                label_widget,
                menu_icon,
            },
            item_alignment = Widget.alignment.CENTER,
        }),
        clip = true,
        padding = entry_style.padding,
        height = entry_style.height,
        width = Widget.length.Fill,
        valign = Widget.alignment.CENTER,
        style = {
            background_color = entry_style.bg_color,
            border = entry_style.border,
        },
    })
end

function MenuEntry:view(active, style)
    local _icons = require("glacier.misc.icons")

    if self._node:is_submenu() then
        return Menu.entry.default_menu_view(self, active, style)
    elseif self._node:is_checkbox() then
        return self:view_toggle(active, style, _icons.checkbox.select(self._node:is_toggled()))
    elseif self._node:is_radio() then
        return self:view_toggle(active, style, _icons.radio.select(self._node:is_toggled()))
    else
        return Menu.entry.default_entry_view(self, active, style)
    end
end

function MenuEntry.new(item, node, menu_config)
    return MenuEntry:super({
        _key = nil,
        _item = item,
        _node = node,
        _menu_config = menu_config,
    })
end

---Action to execute upon update.
---
---@class glacier.widget.systray.MessageAction
---@field action glacier.widget.systray.Action
---@field item string

---@enum glacier.widget.systray.Action
_systray.Action = {
    ACTIVATE = "systray::activate_item",
    DEACTIVATE = "systray::deactivate_item",
    ENTER = "systray::enter_item",
    EXIT = "systray::exit_item",
    ---@param item string
    ---@return glacier.widget.systray.MessageAction
    Activate = function(item)
        return { action = _systray.Action.ACTIVATE, item = item }
    end,
    ---@param item string
    ---@return glacier.widget.systray.MessageAction
    Deactivate = function(item)
        return { action = _systray.Action.DEACTIVATE, item = item }
    end,

    ---@param item string
    ---@return glacier.widget.systray.MessageAction
    Enter = function(item)
        return { action = _systray.Action.ENTER, item = item }
    end,

    ---@param item string
    ---@return glacier.widget.systray.MessageAction
    Exit = function(item)
        return { action = _systray.Action.EXIT, item = item }
    end,
}

---@class glacier.widget.systray.IconStyle
---@field border? snowcap.widget.Border
---@field padding? snowcap.widget.Padding
---@field bg_color? snowcap.widget.Color

local _icon_style_keys = {
    border = 1,
    padding = 1,
    bg_color = 1,
}

---@class glacier.widget.systray.Style
---@field bg_color? snowcap.widget.Color Background color for the whole systray.
---@field border? snowcap.widget.Border Border around the whole systray.
---@field spacing? number Spacing between icons.
---@field padding? snowcap.widget.Padding Padding for the whole row of icons.
---@field active? glacier.widget.systray.IconStyle Style
---@field hovered? glacier.widget.systray.IconStyle
---@field active_hovered? glacier.widget.systray.IconStyle Style
---@field default? glacier.widget.systray.IconStyle

---@return glacier.widget.systray.Style
function systray.default_style()
    ---@type glacier.widget.systray.Style
    return {
        bg_color = nil,
        border = nil,
        spacing = 1,
        padding = nil,
        active = nil,
        hovered = nil,
        default = {
            padding = {
                top = 2,
                left = 2,
                right = 2,
                bottom = 2,
            },
        },
    }
end

---@package
---@param style glacier.widget.systray.Style
---@return glacier.widget.systray.IconStyle
function _systray._get_active_style(style)
    if not style.active then
        return style.default
    end

    return {
        border = style.active.border or style.default.border,
        padding = style.active.padding or style.default.padding,
        bg_color = style.active.bg_color or style.default.bg_color,
    }
end

---@package
---@param style glacier.widget.systray.Style
---@return glacier.widget.systray.IconStyle
function _systray._get_hovered_style(style)
    if not style.hovered then
        return style.default
    end

    return {
        border = style.hovered.border or style.default.border,
        padding = style.hovered.padding or style.default.padding,
        bg_color = style.hovered.bg_color or style.default.bg_color,
    }
end

---@package
---@param style glacier.widget.systray.Style
---@return glacier.widget.systray.IconStyle
function _systray._get_active_hovered_style(style)
    local active = style.active or {}
    local hovered = style.hovered or {}
    local active_hovered = style.active_hovered or {}

    ---@type glacier.widget.systray.IconStyle
    local icon_style = {}

    for k, _ in pairs(_icon_style_keys) do
        icon_style[k] = active_hovered[k] or active[k] or hovered[k] or style.default[k]
    end

    return icon_style
end

---@package
---@param style glacier.widget.systray.Style
---@param active boolean
---@param hovered boolean
---@return glacier.widget.systray.IconStyle
function _systray.get_icon_style(style, active, hovered)
    if active and hovered then
        return _systray._get_active_hovered_style(style)
    elseif active then
        return _systray._get_active_style(style)
    elseif hovered then
        return _systray._get_hovered_style(style)
    else
        return style.default
    end
end

---@alias glacier.widget.systray.ViewFn fun(items: snowcap.widget.WidgetDef[], style:glacier.widget.systray.Style): snowcap.widget.WidgetDef

---@param children snowcap.widget.WidgetDef[]
---@param style glacier.widget.systray.Style
function systray.default_view(children, style)
    return Widget.container({
        child = Widget.row({
            height = Widget.length.Fill,
            item_alignment = Widget.alignment.CENTER,
            spacing = style.spacing,
            children = children,
        }),
        padding = style.padding,
        style = {
            border = style.border,
            background_color = style.bg_color,
        },
    })
end

---@alias glacier.widget.systray.IconViewFn fun(item: glacier.status_notifier.host.Item, style: glacier.widget.systray.IconStyle): snowcap.widget.WidgetDef?

---@param item glacier.status_notifier.host.Item
---@param style glacier.widget.systray.IconStyle
function systray.default_icon_view(item, style)
    local _icons = require("glacier.misc.icons")
    local _color = require("glacier.misc.color")
    local icon_name = item.icon_name

    local image_handle
    if icon_name and string.len(icon_name) > 0 then
        local path = item.icon_theme_path .. "/" .. icon_name .. ".png"
        image_handle = {
            path = path,
        }
    else
        local pixmap = item.icon_pixmap[1]

        if pixmap then
            image_handle = {
                rgba = { width = pixmap.x, height = pixmap.y, rgba = pixmap.data },
            }
        end
    end

    if not image_handle then
        local icon_mask = _icons.misc.broken_picture()
        image_handle = icon_mask:to_image_handle(_color.from_hex("#FFFFFF"))
    end

    return Widget.container({
        child = Widget.Image({
            handle = image_handle,
        }),
        padding = style.padding,
        style = {
            border = style.border,
            background_color = style.bg_color,
        },
    })
end

---@class glacier.widget.systray.SysTray: glacier.widget.Base
---@field private _host glacier.status_notifier.Host
---@field private _active string
---@field private _hovered string
---@field private _menu_config glacier.menu.Config
---@field private _menu? glacier.menu.Menu
---@field private _menu_signals? glacier.menu.MenuSignals
---@field private _view_fn? glacier.widget.systray.ViewFn
---@field private _icon_view_fn? glacier.widget.systray.IconViewFn
---@field private _style glacier.widget.systray.Style
local SysTray = Base:new_class({ type = "SysTray" })

function SysTray:_view_icon(key, item)
    local id = item.id

    local icon_style =
        _systray.get_icon_style(self._style, self._active == key, self._hovered == key)
    local icon_view
    if self._icon_view_fn then
        local ok
        ok, icon_view = pcall(self._icon_view_fn, item, icon_style)

        if not ok then
            Log.error(
                ("While calling view function for item %s: %s"):format(item.id, tostring(icon_view))
            )
        end
    else
        icon_view = systray.default_icon_view(item, icon_style)
    end

    if not icon_view then
        return nil
    end

    local marea = Widget.mouse_area({
        child = icon_view,
        on_release = {
            widget_id = self:id(),
            action = _systray.Action.Activate(key),
        },
        on_enter = {
            widget_id = self:id(),
            action = _systray.Action.Enter(key),
        },
        on_exit = {
            widget_id = self:id(),
            action = _systray.Action.Exit(key),
        },
    })

    return Widget.container({
        id = id,
        child = marea,
    })
end

function SysTray:view()
    local children = {}

    for k, item in pairs(self._host:items()) do
        local child = self:_view_icon(k, item)
        table.insert(children, child)
    end

    if self._view_fn then
        local ok, ret = pcall(self._view_fn, children, self._style)
        if not ok then
            Log.error(("While calling Systray's view function: %s"):format(tostring(ret)))
            return nil
        else
            return ret
        end
    end

    return systray.default_view(children, self._style)
end

---@param parent glacier.Surface
function SysTray:_activate_item(item_id, parent)
    local item = self._host:items()[item_id]

    item:about_to_show()

    if item.menu_tree then
        local root = MenuEntry.new(item, item.menu_tree, self._menu_config)
        local menu = root:open_menu()

        if menu then
            local parent_handle = parent:get_handle():as_parent()
            local ok, err = menu:show(parent_handle, nil, {
                position = Popup.position.AtWidget(item.id),
            })
            if not ok then
                Log.error(("While opening menu for %s: %s"):format(item.id, tostring(err)))
                return nil
            end

            self._menu = menu
            self._menu_signals = {
                closed = self._menu:connect(Menu.signal.CLOSED, function()
                    self:emit(signal.send_message, {
                        widget_id = self:id(),
                        action = _systray.Action.Deactivate(item_id),
                    })
                end),
            }

            self._active = item_id
        end
    end
end

---@param msg any
---@param parent glacier.Surface
function SysTray:update(msg, parent)
    if not msg then
        return
    end

    if msg.widget_id == self:id() then
        msg = msg.action --[[@as glacier.widget.systray.MessageAction]]

        if msg.action == _systray.Action.ACTIVATE then
            self:_activate_item(msg.item, parent)
        elseif msg.action == _systray.Action.DEACTIVATE then
            self._active = nil
            self._menu = nil
            self._menu_signals = nil
        elseif msg.action == _systray.Action.ENTER then
            self._hovered = msg.item
        elseif msg.action == _systray.Action.EXIT then
            if self._hovered == msg.item then
                self._hovered = nil
            end
        end
    end
end

function SysTray:refresh()
    self:emit(widget_signal.redraw_needed)
end

---@class glacier.widget.systray.Config
---@field menu_config? glacier.menu.Config
---@field style? glacier.widget.systray.Style
---@field view_fn? glacier.widget.systray.ViewFn
---@field icon_view_fn? glacier.widget.systray.IconViewFn

---@param config glacier.widget.systray.Config
---@return glacier.widget.systray.SysTray
function SysTray:new(config)
    config = config or {}

    ---@type glacier.widget.systray.Config
    local default_config = {
        menu_config = {
            direction = Menu.direction.DownLeft,
            popup_config = {
                anchor = Popup.anchor.BOTTOM_RIGHT,
                offset = { x = 0, y = 8 },
            },
            child_popup_config = {
                offset = { x = -2, y = 0 },
            },
        },
        style = systray.default_style(),
    }

    ---@type glacier.widget.systray.Config
    config = require("glacier.utils").merge_table(default_config, config)

    local ret = SysTray:super({
        _menu_config = config.menu_config,
        _style = config.style,
        _view_fn = config.view_fn,
        _icon_view_fn = config.icon_view_fn,
    })

    local id = ret:id()

    ret._host = SNIHost.new(dbus.session(), ("glacier-%d"):format(id), {
        on_register = function()
            ret:refresh()
        end,
        on_unregister = function()
            ret:refresh()
        end,
    })

    return ret
end

---@param ... glacier.widget.systray.Config
---@return glacier.widget.systray.SysTray
function systray.mt:__call(...)
    return SysTray:new(...)
end

return setmetatable(systray, systray.mt) --[[@as glacier.widget.systray]]
