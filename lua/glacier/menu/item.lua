local Widget = require("snowcap.widget")

local color = require("glacier.misc.color")
local action = require("glacier.menu.action")

--- Menu item submodule
---@class glacier.menu.item
local _item = {}

---@class glacier.menu.item.SeparatorStyle
---@field fg_color? snowcap.widget.Color
---@field bg_color? snowcap.widget.Color
---@field height? snowcap.widget.Length
---@field padding? snowcap.widget.Padding
---@field thickness? number

---@class glacier.menu.item.MenuIndicatorStyle
---@field width? snowcap.widget.Length
---@field height? snowcap.widget.Length
---@field color? snowcap.widget.Color

---@class glacier.menu.item.ItemStyle
---@field fg_color? snowcap.widget.Color
---@field bg_color? snowcap.widget.Color
---@field height? snowcap.widget.Length
---@field padding? snowcap.widget.Padding
---@field border? snowcap.widget.Border

---Styling options for Menu's Item.
---@class glacier.menu.item.Style
---@field font_size? integer Size of the font, in pixel.
---@field font? snowcap.widget.Font
---@field default? glacier.menu.item.ItemStyle
---@field active? glacier.menu.item.ItemStyle
---@field disabled? glacier.menu.item.ItemStyle
---@field menu_indicator? glacier.menu.item.MenuIndicatorStyle
---@field separator? glacier.menu.item.SeparatorStyle

function _item.default_style()
    ---@type glacier.menu.item.Style
    return {
        active = {
            bg_color = color.from_hex("#6B1ABC"),
        },
        disabled = {
            fg_color = color.from_hex("#5b5b5b"),
        },
        default = {
            fg_color = color.from_hex("#d7d7d7"),
            padding = { left = 2, right = 2 },
        },
        separator = {
            fg_color = color.from_hex("#131313"),
            height = Widget.length.Fixed(1),
            padding = { left = 8, right = 8, top = 3, bottom = 3 },
            thickness = 1,
        },
        menu_indicator = {
            width = Widget.length.Fixed(12),
            height = Widget.length.Fixed(12),
            color = color.from_hex("#7b7b7b"),
        },
    }
end

---@enum glacier.menu.item.State
_item.state = {
    ACTIVE = "active",
    DISABLED = "disabled",
    DEFAULT = "default",
}

---@param item glacier.menu.Item
---@param active boolean
---@return glacier.menu.item.State
function _item.get_state(item, active)
    if item:disabled() then
        return _item.state.DISABLED
    elseif active then
        return _item.state.ACTIVE
    else
        return _item.state.DEFAULT
    end
end

function _item.item_style_for_state(style, state)
    local default = style.default
    state = state or _item.state.DEFAULT

    if state == _item.state.DEFAULT then
        return default
    elseif style[state] == nil then
        return default
    end

    ---@type glacier.menu.item.ItemStyle
    return {
        bg_color = style[state].bg_color or default.bg_color,
        fg_color = style[state].fg_color or default.fg_color,
        height = style[state].height or default.height,
        padding = style[state].padding or default.padding,
        norder = style[state].border or default.border,
    }
end

---@alias glacier.menu.item.ViewFn fun(self: self, active: boolean, style: glacier.menu.item.Style): snowcap.widget.WidgetDef?
---@alias glacier.menu.item.UpdateFn fun(self: self, message: any, surface: glacier.Surface): glacier.menu.Message?
---@alias glacier.menu.item.ActivateFn fun(self: self, hover: boolean): glacier.menu.Message?
---@alias glacier.menu.item.DeactivateFn fun(self: self)
---@alias glacier.menu.item.SubmitFn fun(self: self): glacier.menu.Message?
---@alias glacier.menu.item.OpenMenuFn fun(self: self): glacier.menu.Menu

---Item's shared interface
---
---@class glacier.menu.Item
---@field activate? glacier.menu.item.ActivateFn Called when the item is selected.
---@field deactivate? glacier.menu.item.DeactivateFn Called when the item stop being selected.
---@field update? glacier.menu.item.UpdateFn Called on update to forward message.
---@field submit? glacier.menu.item.SubmitFn Called when the item is being submitted.
---@field open_menu? glacier.menu.item.OpenMenuFn Called when the item should open its menu.
local Item = {}

---Get the item key.
---@return string?
function Item:key() end

---Set the item key.
---@param key string
function Item:set_key(key) end ---@diagnostic disable-line:unused-local

---Called when the item gets selected
---@param hover boolean True if the item is was selected via a mouse hovering.
---@return glacier.menu.Message?
function Item:activate(hover) end ---@diagnostic disable-line:unused-local

---Called when the item is no longer selected.
function Item:deactivate() end

---@return string
function Item:label() end ---@diagnostic disable-line:missing-return

---@return boolean
function Item:disabled() end ---@diagnostic disable-line:missing-return

---@param active boolean
---@param style glacier.menu.item.Style
---@return snowcap.widget.WidgetDef?
function Item:view(active, style) end ---@diagnostic disable-line:unused-local

---@param self glacier.menu.Item
---@param style glacier.menu.item.Style
---@return snowcap.widget.WidgetDef
function _item.default_item_view(self, active, style)
    local state = _item.get_state(self, active)
    local item_style = _item.item_style_for_state(style, state)

    return Widget.container({
        child = Widget.text({
            text = self:label(),
            style = {
                color = item_style.fg_color,
                font = style.font,
                pixels = style.font_size,
            },
        }),
        clip = true,
        padding = item_style.padding,
        height = item_style.height,
        width = Widget.length.Fill,
        style = {
            background_color = item_style.bg_color,
            border = item_style.border,
        },
    })
end

---@param self glacier.menu.Item
---@param style glacier.menu.item.Style
---@return snowcap.widget.WidgetDef
function _item.default_menu_view(self, active, style)
    local state = _item.get_state(self, active)
    local item_style = _item.item_style_for_state(style, state)

    local label_widget = Widget.text({
        text = self:label(),
        width = Widget.length.Fill,
        style = {
            color = item_style.fg_color,
            font = style.font,
            pixels = style.font_size,
        },
    })

    local _icons = require("glacier.misc.icons")
    local menu_icon_handle = _icons.menu
        .menu_indicator()
        :to_image_handle(style.menu_indicator.color or item_style.fg_color)
    local menu_icon = Widget.Image({
        handle = menu_icon_handle,
        content_fit = Widget.image.content_fit.SCALE_DOWN,
        height = style.menu_indicator.height,
        width = style.menu_indicator.width,
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
        padding = item_style.padding,
        height = item_style.height,
        width = Widget.length.Fill,
        valign = Widget.alignment.CENTER,
        style = {
            background_color = item_style.bg_color,
            border = item_style.border,
        },
    })
end

----------------------
-- Simple Items     --
----------------------

----------------------
-- Base             --
----------------------

---Common item implementation.
---@class glacier.menu.item.ItemBase: glacier.menu.Item
---@field protected _key string?
---@field protected _label string
---@field protected _disabled boolean
local ItemBase = {}
ItemBase.__index = ItemBase
ItemBase.__name = "glacier.menu.item.ItemBase"

function ItemBase:new_type()
    return setmetatable({}, self)
end

function ItemBase:super(o)
    o = o or {}

    o = setmetatable(o, self)

    return o
end

function ItemBase:key()
    return self._key
end

function ItemBase:set_key(key)
    self._key = key
end

function ItemBase:label()
    return self._label
end

function ItemBase:disabled()
    return self._disabled
end

---Render an item using the default view.
---
---@param active boolean
---@param style glacier.menu.item.Style
---@return snowcap.widget.WidgetDef
function ItemBase:view(active, style)
    return _item.default_item_view(self, active, style)
end

_item.ItemBase = ItemBase

----------------------
-- Item             --
----------------------

---@class glacier.menu.item.SimpleItem: glacier.menu.item.ItemBase
---@field private _on_submit glacier.menu.item.SubmitFn
local SimpleItem = ItemBase:new_type()
SimpleItem.__index = SimpleItem
SimpleItem.__name = "glacier.menu.SimpleItem"

function SimpleItem.new(label, on_submit)
    local self = SimpleItem:super({
        _label = label,
        _disabled = on_submit == nil,
        _on_submit = on_submit,
    })

    return self
end

function SimpleItem:submit()
    local ret

    if not self._disabled and self._on_submit then
        ret = self._on_submit(self)
    end

    return ret or action.menu.Close()
end

_item.SimpleItem = SimpleItem

function _item.simple_item(label, on_submit)
    return SimpleItem.new(label, on_submit)
end

----------------------
-- Menu             --
----------------------

---@class glacier.menu.item.SimpleMenu: glacier.menu.item.ItemBase
---@field private _on_open_menu glacier.menu.item.OpenMenuFn
local SimpleMenu = ItemBase:new_type()
SimpleMenu.__index = SimpleMenu
SimpleMenu.__name = "glacier.menu.item.SimpleMenu"

function SimpleMenu.new(label, on_open_menu)
    local self = SimpleMenu:super({
        _label = label,
        _disabled = on_open_menu == nil,
        _on_open_menu = on_open_menu,
    })

    return self
end

function SimpleMenu:activate(hover)
    if hover then
        return action.item.OpenMenu()
    end
end

function SimpleMenu:submit()
    if not self._disabled and self._on_open_menu then
        return action.item.OpenMenu()
    end
end

function SimpleMenu:open_menu()
    if self._on_open_menu then
        return self._on_open_menu(self)
    end
end

function SimpleMenu:view(active, style)
    return _item.default_menu_view(self, active, style)
end

_item.SimpleMenu = SimpleMenu
function _item.simple_menu(label, on_open_menu)
    return SimpleMenu.new(label, on_open_menu)
end

---@class glacier.menu.item.Separator: glacier.menu.Item
local Separator = {}
Separator.__index = Separator
Separator.__name = "glacier.menu.item.Separator"

function Separator.new()
    return setmetatable({}, Separator)
end

function Separator:key()
    return "#glacier-item-menu-separator"
end

function Separator:set_key(_) end

function Separator:disabled()
    return true
end

function Separator:label()
    return ""
end

function Separator:view(active, style)
    _ = active
    return Widget.container({
        padding = style.separator.padding,
        child = Widget.container({
            child = Widget.column({ children = {} }),
            width = Widget.length.Fill,
            height = style.separator.height,
            style = {
                background_color = style.separator.bg_color,
                border = {
                    width = style.separator.thickness,
                    color = style.separator.fg_color,
                },
            },
        }),
    })
end

_item.Separator = Separator
function _item.separator()
    return Separator.new()
end

return _item
