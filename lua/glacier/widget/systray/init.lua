local _base = require("snowcap.widget.base")
local Popup = require("snowcap.popup")
local Widget = require("snowcap.widget")

local icons = require("glacier.misc.icons")
local utils = require("glacier.utils")
local color = require("glacier.misc.color")
local sni = require("glacier.services.status_notifier")

local _menu = require("glacier.widget.systray.menu")

---@class glacier.widget.systray
---@field mt metatable
---
---@overload fun(...: glacier.widget.systray.Config): glacier.widget.SysTray
local systray = { mt = {} }

----------------------
-- Type Definitions --
----------------------

---@alias glacier.widget.systray.ViewCallback fun()

---@alias glacier.widget.systray.ItemViewCallback fun()

---@class glacier.widget.systray.ItemUpdate
---@field item_id string
---@field update glacier.services.status_notifier.ItemUpdate

---@class glacier.widget.systray.MenuOpened
---@field item_id string
---@field menu glacier.menu.Menu

---@class glacier.widget.systray.Event
---@field hover_start? string
---@field hover_stop? string
---@field activate? string
---@field toggle_menu? string
---@field item_added? glacier.widget.systray.Item
---@field item_updated? glacier.widget.systray.ItemUpdate
---@field item_removed? string
---@field menu_opened? glacier.widget.systray.MenuOpened
---@field menu_closed? string

---@class glacier.widget.systray.Message
---@field id integer
---@field event glacier.widget.systray.Event
local Message = {}

---@class glacier.widget.systray.OpenMenu
---@field item_id string
---@field close_sig snowcap.signal.SignalHandle
---@field handle glacier.menu.Handle

---@class glacier.widget.systray.Item
---@field unique_id string
---@field id string
---
---@field icon snowcap.widget.image.Handle?
---@field attention_icon snowcap.widget.image.Handle?
---
---@field status glacier.protocols.status_notifier.ItemProxy.status
---@field is_menu boolean

---@class glacier.widget.systray.IconStyle
---@field bg_color? snowcap.widget.Color
---@field border? snowcap.widget.Border
---@field padding? snowcap.widget.Padding

---@class glacier.widget.systray.Style
---@field bg_color? snowcap.widget.Color
---@field border? snowcap.widget.Border
---@field spacing? number
---@field padding? snowcap.widget.Padding
---@field menu? glacier.menu.Style
---
---@field active? glacier.widget.systray.IconStyle
---@field hovered? glacier.widget.systray.IconStyle
---@field active_hovered? glacier.widget.systray.IconStyle
---@field default? glacier.widget.systray.IconStyle
local Style = {}

---@class glacier.widget.systray.Config
---@field service glacier.services.StatusNotifier
---@field style? glacier.widget.systray.Style
---@field view_callback? glacier.widget.systray.ViewCallback
---@field item_view_callback? glacier.widget.systray.ItemViewCallback
---
---@field menu_config? glacier.menu.PopupConfig
---@field submenu_config? glacier.menu.PopupConfig

---@class glacier.widget.SysTray: snowcap.widget.Program
---@field private _service glacier.services.StatusNotifier
---@field private _style glacier.widget.systray.Style
---@field private _view_callback? glacier.widget.systray.ViewCallback
---@field private _item_view_callback? glacier.widget.systray.ItemViewCallback
---
---@field private _menu_config glacier.menu.PopupConfig
---@field private _submenu_config glacier.menu.PopupConfig
---
---@field private _items glacier.widget.systray.Item[]
---@field private _hovered string?
---@field private _open_menu glacier.widget.systray.OpenMenu?
---
---@field private _surface snowcap.widget.SurfaceHandle?
local SysTray = setmetatable({}, { __index = _base.Base })

---------------------
-- Module function --
---------------------

---@param overrides? glacier.widget.systray.Style
---@return glacier.widget.systray.Style
function systray.default_style(overrides)
    ---@type glacier.widget.systray.Style
    local default_style = {
        spacing = 1.,
        default = {
            padding = {
                top = 2.,
                bottom = 2.,
                left = 2.,
                right = 2.,
            },
        },
        hovered = {
            bg_color = color.from_hex("#575757"),
        },
        active = {
            bg_color = color.from_hex("#474747"),
        },
        menu = require("glacier.menu").default_style(),
    }

    return utils.merge_table(default_style, overrides)
end

---@param overrides? glacier.menu.PopupConfig
---@return glacier.menu.PopupConfig
function systray.default_menu_config(overrides)
    ---@type glacier.menu.PopupConfig
    local default_config = {
        anchor = Popup.anchor.BOTTOM_RIGHT,
        gravity = Popup.gravity.BOTTOM_LEFT,
        offset = { x = 0, y = 8 },
    }

    return utils.merge_table(default_config, overrides)
end

---@param overrides? glacier.menu.PopupConfig
---@return glacier.menu.PopupConfig
function systray.default_submenu_config(overrides)
    return systray.default_menu_config(utils.merge_table({
        anchor = Popup.anchor.TOP_LEFT,
        offset = { x = -2, y = 0 },
    }, overrides))
end

---Default view for Systray
---
---@param children snowcap.widget.WidgetDef[]
---@param style glacier.widget.systray.Style
---
---@return snowcap.widget.WidgetDef?
function systray.default_view(children, style)
    return Widget.container({
        child = Widget.row({
            children = children,
            height = Widget.length.Fill,
            item_alignment = Widget.alignment.CENTER,
            spacing = style.spacing,
        }),
        padding = style.padding,
        style = {
            background = style.bg_color and Widget.background.Color(style.bg_color) or nil,
            border = style.border,
        },
    })
end

---Default view for Systray's Item.
---
---@param item glacier.widget.systray.Item
---@param style glacier.widget.systray.IconStyle
---
---@return snowcap.widget.WidgetDef?
function systray.default_item_view(item, style)
    local icon = item.icon or icons.misc.broken_picture():to_image_handle(color.from_hex("#FFFFFF"))
    local attention_icon = item.attention_icon or item.icon

    local image_handle = item.status == "NeedsAttention" and attention_icon or icon

    --if image_handle.path == nil then
    --return
    --end

    return Widget.container({
        child = Widget.Image({
            handle = image_handle,
        }),
        padding = style.padding,
        style = {
            background = style.bg_color and Widget.background.Color(style.bg_color) or nil,
            border = style.border,
        },
    })
end

---@package
---@return glacier.widget.systray.IconStyle
function Style:get_active_style()
    local deep_copy = require("snowcap.util").deep_copy
    local default = deep_copy(self.default) or {}
    local active = deep_copy(self.active) or {}

    active.bg_color = active.bg_color or default.bg_color
    active.border = active.border or default.border
    active.padding = active.padding or default.padding

    return active
end

---@package
---@return glacier.widget.systray.IconStyle
function Style:get_hovered_style()
    local deep_copy = require("snowcap.util").deep_copy
    local default = deep_copy(self.default) or {}
    local hovered = deep_copy(self.hovered) or {}

    hovered.bg_color = hovered.bg_color or default.bg_color
    hovered.border = hovered.border or default.border
    hovered.padding = hovered.padding or default.padding

    return hovered
end

---@package
---@return glacier.widget.systray.IconStyle
function Style:get_active_hovered_style()
    local deep_copy = require("snowcap.util").deep_copy
    local default = deep_copy(self.default) or {}
    local active = deep_copy(self.active) or {}
    local hovered = deep_copy(self.hovered) or {}
    local active_hovered = deep_copy(self.active_hovered) or {}

    active_hovered.bg_color = active_hovered.bg_color
        or active.bg_color
        or hovered.bg_color
        or default.bg_color
    active_hovered.border = active_hovered.border
        or active.border
        or hovered.border
        or default.border
    active_hovered.padding = active_hovered.padding
        or active.padding
        or hovered.padding
        or default.padding

    return active_hovered
end

---@package
---@param active boolean
---@param hovered boolean
---
---@return glacier.widget.systray.IconStyle
function Style:get_icon_style(active, hovered)
    if active and hovered then
        return self:get_active_hovered_style()
    elseif active then
        return self:get_active_style()
    elseif hovered then
        return self:get_hovered_style()
    else
        return require("snowcap.util").deep_copy(self.default or {})
    end
end

---@param style glacier.widget.systray.Style
---@return glacier.widget.systray.Style
function Style.new(style)
    return setmetatable(style, { __index = Style })
end

------------------
-- Message Impl --
------------------

---@param id integer
---@param item_id string
---
---@return glacier.widget.systray.Message
function Message.hover_start(id, item_id)
    ---@type glacier.widget.systray.Message
    return {
        id = id,
        event = {
            hover_start = item_id,
        },
    }
end

---@param id integer
---@param item_id string
---
---@return glacier.widget.systray.Message
function Message.hover_stop(id, item_id)
    ---@type glacier.widget.systray.Message
    return {
        id = id,
        event = {
            hover_stop = item_id,
        },
    }
end

---@param id integer
---@param item_id string
---
---@return glacier.widget.systray.Message
function Message.activate(id, item_id)
    ---@type glacier.widget.systray.Message
    return {
        id = id,
        event = {
            activate = item_id,
        },
    }
end

---@param id integer
---@param item_id string
---
---@return glacier.widget.systray.Message
function Message.toggle_menu(id, item_id)
    ---@type glacier.widget.systray.Message
    return {
        id = id,
        event = {
            toggle_menu = item_id,
        },
    }
end

---@param id integer
---@param item_id string
---
---@return glacier.widget.systray.Message
function Message.menu_closed(id, item_id)
    ---@type glacier.widget.systray.Message
    return {
        id = id,
        event = {
            menu_closed = item_id,
        },
    }
end

---@param id integer
---@param item glacier.widget.systray.Item
---
---@return glacier.widget.systray.Message
function Message.item_added(id, item)
    ---@type glacier.widget.systray.Message
    return {
        id = id,
        event = {
            item_added = item,
        },
    }
end

---@param id integer
---@param item_id string
---@param update glacier.services.status_notifier.ItemUpdate
---
---@return glacier.widget.systray.Message
function Message.item_updated(id, item_id, update)
    ---@type glacier.widget.systray.Message
    return {
        id = id,
        event = {
            item_updated = {
                item_id = item_id,
                update = update,
            },
        },
    }
end

---@param id integer
---@param item_id string
---
---@return glacier.widget.systray.Message
function Message.item_removed(id, item_id)
    ---@type glacier.widget.systray.Message
    return {
        id = id,
        event = {
            item_removed = item_id,
        },
    }
end

---@param item glacier.services.status_notifier.ItemState
local function Item_new(item)
    ---@type glacier.widget.systray.Item
    local ret = {
        unique_id = item.unique_id,
        id = item.id,
        status = item.status,
        icon = item.icon,
        attention_icon = item.attention_icon,
        is_menu = item.is_menu,
    }

    return ret
end

------------------
-- SysTray Impl --
------------------

---------------------
-- Private Methods --
---------------------

---@private
---@param msg any|glacier.widget.systray.Message
---
---@return glacier.widget.systray.Event?
function SysTray:get_message_event(msg)
    if msg.id == self:id() then
        return msg.event
    end
end

function SysTray:get_initial_state()
    local items = self._service:items()

    self._items = {}
    for _, v in ipairs(items) do
        table.insert(self._items, Item_new(v))
    end
end

function SysTray:connect_service_signals()
    local Signal = require("snowcap.signal")
    local StdSig = require("snowcap.widget.signal")

    local weak = utils.weak(self:signaler())
    local id = self:id()

    self._service:connect(sni.signal.ITEM_ADDED, function(state)
        local signaler = weak:get()
        if not signaler then
            return Signal.HandlerPolicy.Discard
        end

        local item = Item_new(state)
        signaler:emit(StdSig.send_message, Message.item_added(id, item))
    end)

    self._service:connect(sni.signal.ITEM_UPDATED, function(item_id, update)
        local signaler = weak:get()
        if not signaler then
            return Signal.HandlerPolicy.Discard
        end

        signaler:emit(StdSig.send_message, Message.item_updated(id, item_id, update))
    end)

    self._service:connect(sni.signal.ITEM_REMOVED, function(item_id)
        local signaler = weak:get()
        if not signaler then
            return Signal.HandlerPolicy.Discard
        end

        signaler:emit(StdSig.send_message, Message.item_removed(id, item_id))
    end)
end

---@param item glacier.widget.systray.Item
function SysTray:view_item(item)
    local uid = item.unique_id

    local style = self._style:get_icon_style(
        self._open_menu and self._open_menu.item_id == uid or false,
        self._hovered == uid
    )

    local view_callback = self._item_view_callback or systray.default_item_view
    local view = view_callback(item, style)

    if not view then
        return
    end

    local mouse_area = Widget.mouse_area({
        child = view,
        on_enter = Message.hover_start(self:id(), uid),
        on_exit = Message.hover_stop(self:id(), uid),
        on_release = Message.activate(self:id(), uid),
        on_right_release = Message.toggle_menu(self:id(), uid),
    })

    return Widget.container({
        child = mouse_area,
        id = uid,
    })
end

function SysTray:find_item(item_id)
    for _, item in ipairs(self._items) do
        if item.unique_id == item_id then
            return item
        end
    end
end

function SysTray:close_menu()
    local open_menu = self._open_menu
    self._open_menu = nil

    if not open_menu then
        return
    end

    open_menu.close_sig:disconnect()
    open_menu.handle:close()
end

function SysTray:activate(item_id)
    self:close_menu()
    local item = self:find_item(item_id)

    if not item then
        return
    end

    if item.is_menu then
        self:toggle_menu_impl(item)
    else
        self:activate_impl(item)
    end
end

---@param item_id string
---@param menu glacier.menu.Menu
function SysTray:open_menu(item_id, menu)
    self:close_menu()

    if not self._surface then
        return
    end

    local item = self:find_item(item_id)
    if not item then
        return
    end

    local StdSig = require("snowcap.widget.signal")
    local Signals = require("snowcap.signal")

    local msg = Message.menu_closed(self:id(), item_id)
    local weak = utils.weak(self:signaler())

    local close_sig = menu:connect(StdSig.closed, function()
        local signaler = weak:get()

        if not signaler then
            return Signals.HandlerPolicy.Discard
        end

        signaler:emit(StdSig.send_message, msg)
        return Signals.HandlerPolicy.Discard
    end)

    local subconfig = require("snowcap.util").deep_copy(self._submenu_config)
    local config = require("snowcap.util").deep_copy(self._menu_config)

    menu:set_submenu_config(subconfig)
    local handle = menu:popup(self._surface:as_parent(), Popup.position.AtWidget(item_id), config)

    if handle then
        self._open_menu = {
            item_id = item_id,
            close_sig = close_sig,
            handle = handle,
        }
    end
end

---@param item glacier.widget.systray.Item
function SysTray:activate_impl(item)
    self._service:activate_item(item.unique_id)
end

function SysTray:toggle_menu(item_id)
    self:close_menu()

    local item = self:find_item(item_id)
    self:toggle_menu_impl(item)
end

---@param item glacier.widget.systray.Item
function SysTray:toggle_menu_impl(item)
    local nodes = self._service:open_menu(item.unique_id, 0)

    if nodes then
        local menu = _menu.make_menu(nodes, self._service, item.unique_id, self._menu_config)
        self:open_menu(item.unique_id, menu)
    end
end

---@private
---@param item_id string
---@param update glacier.services.status_notifier.ItemUpdate
function SysTray:update_item(item_id, update)
    ---@type glacier.widget.systray.Item?
    local item

    for _, i in ipairs(self._items) do
        if i.unique_id == item_id then
            item = i
            break
        end
    end

    if not item then
        return
    end

    if update.icon then
        item.icon = update.icon
    elseif update.attention_icon then
        item.attention_icon = update.attention_icon
    elseif update.status then
        item.status = update.status
    end
end

---------------------
-- Public Methods --
---------------------

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
function SysTray:view()
    local children_view = {}

    for _, item in ipairs(self._items) do
        local view = self:view_item(item)

        if view then
            table.insert(children_view, view)
        end
    end

    local view_callback = self._view_callback or systray.default_view

    return view_callback(children_view, require("snowcap.util").deep_copy(self._style))
end

---Updates this widget program with the received message.
---@param msg any|glacier.widget.systray.Message
function SysTray:update(msg)
    local event = self:get_message_event(msg)

    if not event then
        return
    end

    if event.hover_start then
        self._hovered = event.hover_start
    elseif event.hover_stop then
        if self._hovered == event.hover_stop then
            self._hovered = nil
        end
    elseif event.activate then
        self:activate(event.activate)
    elseif event.toggle_menu then
        self:toggle_menu(event.toggle_menu)
    elseif event.item_added then
        table.insert(self._items, event.item_added)
    elseif event.item_updated then
        self:update_item(event.item_updated.item_id, event.item_updated.update)
    elseif event.item_removed then
        local idx
        for i, item in ipairs(self._items) do
            if item.unique_id == event.item_removed then
                idx = i
                break
            end
        end

        if idx then
            table.remove(self._items, idx)
        end
        --elseif event.menu_opened then
        --self:open_menu(event.menu_opened.item_id, event.menu_opened.menu)
    elseif event.menu_closed then
        if self._open_menu and self._open_menu.item_id == event.menu_closed then
            self._open_menu = nil
        end
    end
end

---Called when a surface has been created with this program.
---
---A surface handle is provided to allow the program to manupulate
---the surface. This handle should be passed to any child programs
---to allow them to use it as well.
---
---@param event snowcap.widget.SurfaceEvent
function SysTray:event(event)
    if event.created then
        self:get_initial_state()
        self:connect_service_signals()

        self._surface = event.created
    end
end

-----------
-- Other --
-----------

---@param config glacier.widget.systray.Config
---
---@return glacier.widget.SysTray
function SysTray:new(config)
    local base = _base.Base.new()
    local ret = setmetatable(base, { __index = SysTray }) --[[@as glacier.widget.SysTray]]

    ret._service = config.service
    ret._style = Style.new(config.style or systray.default_style())
    ret._menu_config = config.menu_config or systray.default_menu_config()
    ret._submenu_config = config.submenu_config or systray.default_submenu_config()

    ret._items = {}
    ret._hovered = nil

    return ret
end

---@param ... glacier.widget.systray.Config
---
---@return glacier.widget.SysTray
function systray.mt:__call(...)
    return SysTray:new(...)
end

systray.SysTray = SysTray

---@diagnostic disable-next-line:param-type-mismatch
return setmetatable(systray, systray.mt) --[[@as glacier.widget.systray]]
