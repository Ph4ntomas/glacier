local Widget = require("snowcap.widget")

local color = require("glacier.misc.color")
local action = require("glacier.menu.action")

--- Menu entry submodule
---@class glacier.menu.entry
local _entry = {}

---@class glacier.menu.entry.SeparatorStyle
---@field fg_color? snowcap.widget.Color
---@field bg_color? snowcap.widget.Color
---@field height? snowcap.widget.Length
---@field padding? snowcap.widget.Padding
---@field thickness? number

---@class glacier.menu.entry.MenuIndicatorStyle
---@field width? snowcap.widget.Length
---@field height? snowcap.widget.Length
---@field color? snowcap.widget.Color

---@class glacier.menu.entry.EntryStyle
---@field fg_color? snowcap.widget.Color
---@field bg_color? snowcap.widget.Color
---@field height? snowcap.widget.Length
---@field padding? snowcap.widget.Padding
---@field border? snowcap.widget.Border

---Styling options for Menu's Entry.
---@class glacier.menu.entry.Style
---@field font_size? integer Size of the font, in pixel.
---@field font? snowcap.widget.Font
---@field default? glacier.menu.entry.EntryStyle
---@field active? glacier.menu.entry.EntryStyle
---@field disabled? glacier.menu.entry.EntryStyle
---@field menu_indicator? glacier.menu.entry.MenuIndicatorStyle
---@field separator? glacier.menu.entry.SeparatorStyle

function _entry.default_style()
    ---@type glacier.menu.entry.Style
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

---@enum glacier.menu.entry.State
_entry.state = {
    ACTIVE = "active",
    DISABLED = "disabled",
    DEFAULT = "default",
}

---@param entry glacier.menu.Entry
---@param active boolean
---@return glacier.menu.entry.State
function _entry.get_state(entry, active)
    if entry:disabled() then
        return _entry.state.DISABLED
    elseif active then
        return _entry.state.ACTIVE
    else
        return _entry.state.DEFAULT
    end
end

function _entry.entry_style_for_state(style, state)
    local default = style.default
    state = state or _entry.state.DEFAULT

    if state == _entry.state.DEFAULT then
        return default
    elseif style[state] == nil then
        return default
    end

    ---@type glacier.menu.entry.EntryStyle
    return {
        bg_color = style[state].bg_color or default.bg_color,
        fg_color = style[state].fg_color or default.fg_color,
        height = style[state].height or default.height,
        padding = style[state].padding or default.padding,
        norder = style[state].border or default.border,
    }
end

---@alias glacier.menu.entry.ViewFn fun(self: self, active: boolean, style: glacier.menu.entry.Style): snowcap.widget.WidgetDef?
---@alias glacier.menu.entry.UpdateFn fun(self: self, message: any, surface: glacier.Surface)
---@alias glacier.menu.entry.ActivateFn fun(self: self, hover: boolean): glacier.menu.Message?
---@alias glacier.menu.entry.DeactivateFn fun(self: self)
---@alias glacier.menu.entry.SubmitFn fun(self: self): glacier.menu.Message?
---@alias glacier.menu.entry.OpenMenuFn fun(self: self): glacier.menu.Menu

---Entry's shared interface
---
---@class glacier.menu.Entry
---@field activate? glacier.menu.entry.ActivateFn Called when the entry is selected.
---@field deactivate? glacier.menu.entry.DeactivateFn Called when the entry stop being selected.
---@field update? glacier.menu.entry.UpdateFn Called on update to forward message.
---@field submit? glacier.menu.entry.SubmitFn Called when the entry is being submitted.
---@field open_menu? glacier.menu.entry.OpenMenuFn Called when the entry should open its menu.
local Entry = {}

---Get the entry key.
---@return string?
function Entry:key() end

---Set the entry key.
---@param key string
function Entry:set_key(key) end ---@diagnostic disable-line:unused-local

---Called when the entry gets selected
---@param hover boolean True if the entry is was selected via a mouse hovering.
---@return glacier.menu.Message?
function Entry:activate(hover) end ---@diagnostic disable-line:unused-local

---Called when the entry is no longer selected.
function Entry:deactivate() end

---@return string
function Entry:label() end ---@diagnostic disable-line:missing-return

---@return boolean
function Entry:disabled() end ---@diagnostic disable-line:missing-return

---@param active boolean
---@param style glacier.menu.entry.Style
---@return snowcap.widget.WidgetDef?
function Entry:view(active, style) end ---@diagnostic disable-line:unused-local

---@param self glacier.menu.Entry
---@param style glacier.menu.entry.Style
---@return snowcap.widget.WidgetDef
function _entry.default_entry_view(self, active, style)
    local state = _entry.get_state(self, active)
    local entry_style = _entry.entry_style_for_state(style, state)

    return Widget.container({
        child = Widget.text({
            text = self:label(),
            style = {
                color = entry_style.fg_color,
                font = style.font,
                pixels = style.font_size,
            },
        }),
        clip = true,
        padding = entry_style.padding,
        height = entry_style.height,
        width = Widget.length.Fill,
        style = {
            background_color = entry_style.bg_color,
            border = entry_style.border,
        },
    })
end

---@param self glacier.menu.Entry
---@param style glacier.menu.entry.Style
---@return snowcap.widget.WidgetDef
function _entry.default_menu_view(self, active, style)
    local state = _entry.get_state(self, active)
    local entry_style = _entry.entry_style_for_state(style, state)

    local label_widget = Widget.text({
        text = self:label(),
        width = Widget.length.Fill,
        style = {
            color = entry_style.fg_color,
            font = style.font,
            pixels = style.font_size,
        },
    })

    local _icons = require("glacier.misc.icons")
    local menu_icon_handle = _icons.menu
        .menu_indicator()
        :to_image_handle(style.menu_indicator.color or entry_style.fg_color)
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

----------------------
-- Simple Entries   --
----------------------

----------------------
-- Base             --
----------------------

---Common entry implementation.
---@class glacier.menu.entry.EntryBase: glacier.menu.Entry
---@field protected _key string?
---@field protected _label string
---@field protected _disabled boolean
local EntryBase = {}
EntryBase.__index = EntryBase
EntryBase.__name = "glacier.menu.entry.EntryBase"

function EntryBase:new_type()
    return setmetatable({}, self)
end

function EntryBase:super(o)
    o = o or {}

    o = setmetatable(o, self)

    return o
end

function EntryBase:key()
    return self._key
end

function EntryBase:set_key(key)
    self._key = key
end

function EntryBase:label()
    return self._label
end

function EntryBase:disabled()
    return self._disabled
end

---Render an entry using the default view.
---
---@param active boolean
---@param style glacier.menu.entry.Style
---@return snowcap.widget.WidgetDef
function EntryBase:view(active, style)
    return _entry.default_entry_view(self, active, style)
end

_entry.EntryBase = EntryBase

----------------------
-- Entry            --
----------------------

---@class glacier.menu.entry.SimpleEntry: glacier.menu.entry.EntryBase
---@field private _on_submit glacier.menu.entry.SubmitFn
local SimpleEntry = EntryBase:new_type()
SimpleEntry.__index = SimpleEntry
SimpleEntry.__name = "glacier.menu.SimpleEntry"

function SimpleEntry.new(label, on_submit)
    local self = SimpleEntry:super({
        _label = label,
        _disabled = on_submit == nil,
        _on_submit = on_submit,
    })

    return self
end

function SimpleEntry:submit()
    local ret

    if not self._disabled and self._on_submit then
        ret = self._on_submit(self)
    end

    return ret or action.menu.Close()
end

_entry.SimpleEntry = SimpleEntry

function _entry.simple_entry(label, on_submit)
    return SimpleEntry.new(label, on_submit)
end

----------------------
-- Menu             --
----------------------

---@class glacier.menu.entry.SimpleMenu: glacier.menu.entry.EntryBase
---@field private _on_open_menu glacier.menu.entry.OpenMenuFn
local SimpleMenu = EntryBase:new_type()
SimpleMenu.__index = SimpleMenu
SimpleMenu.__name = "glacier.menu.entry.SimpleMenu"

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
        return action.entry.OpenMenu()
    end
end

function SimpleMenu:submit()
    if not self._disabled and self._on_open_menu then
        return action.entry.OpenMenu()
    end
end

function SimpleMenu:open_menu()
    if self._on_open_menu then
        return self._on_open_menu(self)
    end
end

function SimpleMenu:view(active, style)
    return _entry.default_menu_view(self, active, style)
end

_entry.SimpleMenu = SimpleMenu
function _entry.simple_menu(label, on_open_menu)
    return SimpleMenu.new(label, on_open_menu)
end

---@class glacier.menu.entry.Separator: glacier.menu.Entry
local Separator = {}
Separator.__index = Separator
Separator.__name = "glacier.menu.entry.Separator"

function Separator.new()
    return setmetatable({}, Separator)
end

function Separator:key()
    return "#glacier-entry-menu-separator"
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

_entry.Separator = Separator
function _entry.separator()
    return Separator.new()
end

return _entry
