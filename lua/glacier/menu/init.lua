local Log = require("snowcap.log")
local Popup = require("snowcap.popup")
local Widget = require("snowcap.widget")

local color = require("glacier.misc.color")
local signal = require("glacier.signal")

---glacier.menu module.
---@class glacier.menu
local menu = { mt = {} }

local _signal = {
    REQUEST_CLOSE = "menu::close_requested",
    ---Emitted when a child popup is being closed.
    CLOSING = "menu::closing",
    ---Emitted when a child popup has close.
    CLOSED = "menu::close",
}
menu.signal = _signal

local _item = require("glacier.menu.item")
menu.item = _item

local _action = require("glacier.menu.action")
menu.action = _action

local message = require("glacier.menu.message")
menu.message = message

---@class glacier.menu.PopupConfig
---@field position? snowcap.popup.Position
---@field anchor? snowcap.popup.Anchor
---@field gravity? snowcap.popup.Gravity
---@field offset? snowcap.popup.Offset
---@field constraint_adj? snowcap.popup.ConstraintsAdjust

---@package
---@enum glacier.menu.HDirection
local hdirection = {
    LEFT = 1,
    RIGHT = 2,
}

---@package
---@enum glacier.menu.VDirection
local vdirection = {
    UP = 1,
    DOWN = 2,
}

---@class glacier.menu.Direction
---@field package horizontal glacier.menu.HDirection
---@field package vertical glacier.menu.VDirection
local Direction = {}
Direction.__index = Direction
Direction.__name = "glacier.menu.Direction"

---@lcat nodoc
---@package
---@param hdir glacier.menu.HDirection
---@param vdir glacier.menu.VDirection
---@return glacier.menu.Direction
function Direction.new(hdir, vdir)
    return setmetatable({
        horizontal = hdir,
        vertical = vdir,
    }, Direction)
end

function Direction:to_anchor()
    local vdir
    if self.vertical == vdirection.UP then
        vdir = "BOTTOM"
    else
        vdir = "TOP"
    end

    local hdir
    if self.horizontal == hdirection.RIGHT then
        hdir = "RIGHT"
    else
        hdir = "LEFT"
    end

    local key = ("%s_%s"):format(vdir, hdir)
    return Popup.anchor[key]
end

function Direction:to_gravity()
    local vdir
    if self.vertical == vdirection.UP then
        vdir = "TOP"
    else
        vdir = "BOTTOM"
    end

    local hdir
    if self.horizontal == hdirection.RIGHT then
        hdir = "RIGHT"
    else
        hdir = "LEFT"
    end

    local key = ("%s_%s"):format(vdir, hdir)
    return Popup.gravity[key]
end

---@enum glacier.menu.direction
local _direction = {
    DownRight = Direction.new(hdirection.RIGHT, vdirection.DOWN),
    DownLeft = Direction.new(hdirection.LEFT, vdirection.DOWN),
    UpRight = Direction.new(hdirection.RIGHT, vdirection.UP),
    UpLeft = Direction.new(hdirection.LEFT, vdirection.UP),
}
menu.direction = _direction

---@class glacier.menu.MenuSignals
---@field close_requested? glacier.signal.SignalHandle
---@field closed? glacier.signal.SignalHandle

---@class glacier.menu.Style
---@field bg_color? snowcap.widget.Color Menu's background color.
---@field width? snowcap.widget.Length Menu's width.
---@field height? snowcap.widget.Length Menu's height.
---@field padding? snowcap.widget.Padding Menu's padding.
---@field spacing? number Spacing between row.
---@field border? snowcap.widget.Border Menu's border.

---@class glacier.menu.KeyConfig
---@field replace? boolean
---@field follow_direction? boolean If true open_menu & close_menu will be flipped if the horizontal direction is LEFT.
---@field next? snowcap.Key[]
---@field prev? snowcap.Key[]
---@field submit? snowcap.Key[]
---@field open_menu? snowcap.Key[]
---@field close_menu? snowcap.Key[]
---@field close? snowcap.Key[]

function menu.default_key_config()
    local Keys = require("snowcap.input.keys")

    ---@type glacier.menu.KeyConfig
    return {
        follow_direction = false,
        next = { Keys.Down },
        prev = { Keys.Up },
        submit = { Keys.Return },
        open_menu = { Keys.Right },
        close_menu = { Keys.Left },
        close = { Keys.Escape },
    }
end

---@alias glacier.menu.ViewFn fun(items: snowcap.widget.WidgetDef[], style: glacier.menu.Style): snowcap.widget.WidgetDef

---Default Menu view
---@param items snowcap.widget.WidgetDef[]
---@param style glacier.menu.Style
---@return snowcap.widget.WidgetDef
function menu.default_view(items, style)
    return Widget.container({
        child = Widget.column({
            children = items,
            spacing = style.spacing,
        }),
        width = style.width,
        height = style.height,
        padding = style.padding,
        style = {
            background_color = style.bg_color,
            border = style.border,
        },
    })
end

---@class glacier.menu.Menu: snowcap.widget.Program, glacier.Surface
---@field private _direction glacier.menu.Direction If set, this will be used to generate an anchor and gravity.
---@field private _popup_config glacier.menu.PopupConfig
---@field private _child_popup_config glacier.menu.PopupConfig
---@field private _view_fn? glacier.menu.ViewFn
---@field private _items glacier.menu.Item[]
---@field private _item_indices table<string, integer>
---@field private _active_idx integer?
---@field private _submenu glacier.menu.Menu?
---@field private _submenu_signals? glacier.menu.MenuSignals
---@field private _emitter glacier.signal.Emitter
---@field private _current_direction glacier.menu.Direction
---@field private _handle? snowcap.popup.PopupHandle
---@field private _key_config glacier.menu.KeyConfig
---@field private _style glacier.menu.Style
---@field private _item_style glacier.menu.item.Style
local Menu = {}
Menu.__index = Menu
Menu.__name = "glacier.Menu"

function Menu:_view_items()
    local item_views = {}

    for idx, item in ipairs(self._items) do
        local child = item:view(self._active_idx == idx, self._item_style)

        local mouse_area = {
            child = child,
        }

        if not item:disabled() then
            mouse_area.on_enter = _action.item.Enter(item)
            mouse_area.on_release = _action.item.Submit()
        end

        local item_view = Widget.container({
            id = item:key(),
            child = Widget.mouse_area(mouse_area),
        })

        table.insert(item_views, item_view)
    end

    return item_views
end

function Menu:view()
    local children = self:_view_items()

    if self._view_fn then
        return self._view_fn(children, self._style)
    else
        return menu.default_view(children, self._style)
    end
end

----------------------
-- Items Handling   --
----------------------

function Menu:_next()
    if #self._items == 0 then
        self._active_idx = nil
        return
    end

    if self._active_idx then
        local start = self._active_idx + 1

        for idx = start, #self._items do
            if not self._items[idx]:disabled() then
                return self:_activate_item(idx)
            end
        end
    end

    local start = 1
    local end_idx = #self._items

    for idx = start, end_idx do
        if idx == self._active_idx then
            return nil
        end

        if not self._items[idx]:disabled() then
            return self:_activate_item(idx)
        end
    end

    return nil
end

function Menu:_previous()
    if #self._items == 0 then
        self._active_idx = nil
        return
    end

    if self._active_idx then
        local start = self._active_idx - 1

        for idx = start, 1, -1 do
            if not self._items[idx]:disabled() then
                return self:_activate_item(idx)
            end
        end
    end

    local start = #self._items
    for idx = start, 1, -1 do
        if idx == self._active_idx then
            return nil
        end

        if not self._items[idx]:disabled() then
            return self:_activate_item(idx)
        end
    end

    return nil
end

function Menu:_active_item()
    local idx = self._active_idx

    return idx and self._items[idx]
end

function Menu:_activate_item(idx, hover)
    local item = self._items[idx]

    if not item or item:disabled() then
        return nil
    end

    if self._active_idx ~= idx then
        self:_deactivate_item()
    end

    self._active_idx = idx

    if not item.activate then
        return
    end

    local ok, ret = pcall(function()
        return item:activate(hover or false)
    end)

    if not ok then
        Log.error(("While calling 'item:activate()': %s"):format(tostring(ret)))
        return nil
    end

    return ret
end

function Menu:_deactivate_item()
    local item = self:_active_item()
    if item and not item:disabled() then
        if item.deactivate then
            local ok, err = pcall(function()
                item:deactivate()
            end)

            if not ok then
                Log.error(("While calling 'item:deactivate': %s"):format(tostring(err)))
            end
        end
    end

    self:_close_submenu()
    self._active_idx = nil
end

function Menu:_submit_item()
    local item = self:_active_item()
    if not item or item:disabled() or not item.submit then
        return nil
    end

    local ok, submit_ret = pcall(function()
        return item:submit()
    end)
    if not ok then
        Log.error(("While calling 'item:submit()': %s"):format(tostring(submit_ret)))
        return
    end

    return submit_ret
end

function Menu:set_item_style(style)
    style = style or {}

    self._item_style = require("glacier.utils").merge_table(_item.default_style(), style)
end

----------------------
-- Child Handling   --
----------------------

function Menu:_close_submenu()
    if not self._submenu then
        return
    end

    self._submenu:disconnect(self._submenu_signals.close_requested)
    self._submenu:disconnect(self._submenu_signals.closed)
    self._submenu_signals = nil

    self._submenu:close()
    self._submenu = nil
end

function Menu:_open_submenu()
    local item = self:_active_item()
    if not item or item:disabled() or not item.open_menu then
        return
    end

    local key = item:key()
    if not key then
        Log.error(("Could not open submenu for '%s': No key"):format(tostring(item)))
        return
    end

    local ok, submenu = pcall(function()
        return item:open_menu()
    end)

    if not ok then
        Log.error(("Could not open submenu for '%s': %s"):format(tostring(item), tostring(submenu)))
        return
    end

    if submenu then
        self:_close_submenu()

        local parent = Popup.parent.Popup(self._handle)
        local direction = self._current_direction

        submenu._popup_config = require("snowcap.util").deep_copy(self._child_popup_config)
        submenu._child_popup_config = require("snowcap.util").deep_copy(self._child_popup_config)
        submenu._style = require("snowcap.util").deep_copy(self._style)
        submenu:set_item_style(self._item_style)
        submenu:set_key_config(self._key_config)

        ---@type glacier.menu.PopupConfig
        local config = {
            position = Popup.position.AtWidget(key),
            anchor = self._child_popup_config.anchor,
            gravity = self._child_popup_config.gravity,
            offset = self._child_popup_config.offset,
        }

        ok, _ = submenu:show(parent, direction, config)
        if ok then
            self._submenu = submenu

            ---@type glacier.menu.MenuSignals
            self._submenu_signals = {
                close_requested = self._submenu:connect(_signal.REQUEST_CLOSE, function()
                    self:send_message(_action.menu.CloseSub())
                end),

                closed = self._submenu:connect(_signal.CLOSED, function()
                    self:send_message(_action.menu.Close())
                end),
            }
        end
    end
end

----------------------
-- Surface Method   --
----------------------

function Menu:_update_items(msg)
    for _, item in ipairs(self._items) do
        if item.update then
            local ok, ret = pcall(function()
                return item:update(msg, self)
            end)

            if not ok then
                Log.error(("During a call to Item:update(): %s"):format(tostring(ret)))
            elseif ret ~= nil then
                return ret
            end
        end
    end

    return nil
end

function Menu:update(msg)
    if not msg then
        return
    end

    while msg do
        local next_msg
        if not message.type(msg) == message.TYPE_NAME then
            next_msg = self:_update_items(msg)
        else
            ---@cast msg glacier.menu.Message

            if msg.action == _action.menu.NEXT then
                next_msg = self:_next()
            elseif msg.action == _action.menu.PREV then
                next_msg = self:_previous()
            elseif msg.action == _action.item.ENTER then
                local idx = self._item_indices[msg.item]
                next_msg = self:_activate_item(idx, true)
            elseif msg.action == _action.item.SUBMIT then
                next_msg = self:_submit_item()
            elseif msg.action == _action.item.OPEN_MENU then
                self:_open_submenu()
            elseif msg.action == _action.menu.CLOSE_SUB then
                self:_close_submenu()
            elseif msg.action == _action.menu.CLOSE then
                self:close()
            end
        end

        msg = next_msg
    end
end

local function _array_to_set(arr)
    local set = {}

    for _, v in ipairs(arr) do
        set[v] = 1
    end

    return set
end

---@param parent snowcap.popup.ParentHandle
---@param direction? glacier.menu.Direction
---@param config? glacier.menu.PopupConfig
---@return boolean # Return true if the menu could be shown, false otherwise.
---@return string? # A string describing the error, if qny.
function Menu:show(parent, direction, config)
    if self._handle then
        self._handle:close()
    end

    config = config or {}

    local position = config.position or self._popup_config.position

    if not position then
        Log.error("Could not spawn popup: Position missing.")
        return false, "Could not spawn popup: Position missing."
    end

    self._current_direction = direction or self._direction
    local anchor = config.anchor or self._popup_config.anchor or self._current_direction:to_anchor()
    local gravity = config.gravity
        or self._popup_config.gravity
        or self._current_direction:to_gravity()
    local offset = config.offset or self._popup_config.offset

    local handle = Popup.new_widget({
        parent = parent,
        program = self,
        position = position,
        anchor = anchor,
        gravity = gravity,
        offset = offset,
    })

    if not handle then
        Log.error("Could not spawn popup")
        return false, "Could not spawn popup."
    end

    self._handle = handle

    self._handle:on_key_event(function(_, event)
        local key_cfg = self._key_config

        local next = _array_to_set(key_cfg.next)
        local prev = _array_to_set(key_cfg.prev)
        local submit = _array_to_set(key_cfg.submit)
        local open_menu = _array_to_set(key_cfg.open_menu)
        local close_menu = _array_to_set(key_cfg.close_menu)
        local close = _array_to_set(key_cfg.close)

        if key_cfg.follow_direction and self._current_direction.horizontal == hdirection.LEFT then
            local tmp = close_menu
            close_menu = open_menu
            open_menu = tmp
        end

        if event.pressed then
            if close[event.key] then
                self:close()
            elseif next[event.key] then
                self._handle:send_message(_action.menu.Next())
            elseif prev[event.key] then
                self._handle:send_message(_action.menu.Prev())
            elseif submit[event.key] then
                self._handle:send_message(_action.item.Submit())
            elseif open_menu[event.key] then
                self._handle:send_message(_action.item.OpenMenu())
            elseif close_menu[event.key] then
                self:emit(_signal.REQUEST_CLOSE)
            end
        end
    end)

    return true
end

function Menu:send_message(msg)
    self._handle:send_message(msg)
end

----------------------
-- Misc             --
----------------------

---@param key_cfg glacier.menu.KeyConfig
function Menu:set_key_config(key_cfg)
    if not key_cfg then
        self._key_config = menu.default_key_config()
        return
    end

    local tmp = {
        next = key_cfg.next or {},
        prev = key_cfg.prev or {},
        submit = key_cfg.submit or {},
        open_menu = key_cfg.open_menu or {},
        close_menu = key_cfg.close_menu or {},
        close = key_cfg.close or {},
    }

    for k, arr in pairs(tmp) do
        if key_cfg.replace and #arr > 0 then
            self._key_config[k] = arr
        else
            for _, key in ipairs(arr) do
                table.insert(self._key_config[k], key)
            end
        end
    end

    self._key_config.replace = key_cfg.replace
    self._key_config.follow_direction = key_cfg.follow_direction
end

---Get the menu's handle.
---@return snowcap.popup.PopupHandle
function Menu:get_handle()
    return self._handle
end

----------------------
-- SIGNALS          --
----------------------

---Connect a callback to a specific signal.
---
---@param name string The name of the signal you're connecting to.
---@return glacier.signal.SignalHandle
function Menu:connect(name, callback)
    return self._emitter:connect(name, callback)
end

---Emit a signal.
---
---@param name string Signal to emit
---@param ... any Parameter to sent to the callbacks
function Menu:emit(name, ...)
    self._emitter:emit(name, self, ...)
end

---Disconnect a given callback.
---
---@param handle glacier.signal.SignalHandle Handle to the callback to disconnect.
function Menu:disconnect(handle)
    self._emitter:disconnect(handle)
end

---Disconnect all signal handlers.
function Menu:disconnect_all()
    self._emitter:disconnect_all()
end

----------------------
-- LIFETIME         --
----------------------

---@param config glacier.menu.Config
function Menu:new(config)
    config = config or {}
    config.style = config.style or {}

    ---@type glacier.menu.Config
    local default_config = {
        direction = _direction.DownRight,
        popup_config = {},
        child_popup_config = {},
        view_fn = nil,
        items = {},
        style = {
            bg_color = color.from_hex("#2b2b2b"),
            width = Widget.length.Fixed(250),
            height = nil,
            padding = nil,
            spacing = 1,
            border = {
                color = color.from_hex("#000"),
                width = 0,
            },
        },
        item_style = _item.default_style(),
    }

    ---@type glacier.menu.Config
    config = require("glacier.utils").merge_table(default_config, config)

    ---@type glacier.menu.Menu
    ---@diagnostic disable-next-line:redefined-local
    local menu = {
        _direction = config.direction,
        _popup_config = config.popup_config,
        _child_popup_config = config.child_popup_config,
        _view_fn = config.view_fn,
        _emitter = signal.emitter(),
        _items = {},
        _item_indices = {},
        _active_idx = nil,
        _submenu = nil,
        _submenu_signals = {},
        _current_direction = config.direction or _direction.DownRight,
        _key_config = menu.default_key_config(),
        _style = config.style,
        _item_style = config.item_style,
    }

    config.items = config.items or {}
    for k, item in ipairs(config.items) do
        if not item:key() then
            local key = ("#%d-%s"):format(k, string.gsub(item:label() or "UNNAMED", " ", "-") or "")
            item:set_key(key)
        end

        table.insert(menu._items, item)
        local key = item:key()

        if key then
            menu._item_indices[key] = #menu._items
        end
    end

    setmetatable(menu, self)
    self.__index = self

    menu:set_key_config(config.key_config)

    return menu
end

function Menu:close()
    if self._handle then
        self:emit(_signal.CLOSING)
        self._handle:close()
        self:emit(_signal.CLOSED)
        self:disconnect_all()
    end
    self._handle = nil
end

menu.Menu = Menu

---@class glacier.menu.Config
---@field direction? glacier.menu.Direction If set, this will be used to generate an anchor and gravity.
---@field popup_config? glacier.menu.PopupConfig
---@field child_popup_config? glacier.menu.PopupConfig
---@field view_fn? glacier.menu.ViewFn
---@field key_config? glacier.menu.KeyConfig
---@field style? glacier.menu.Style
---@field item_style? glacier.menu.item.Style
---@field items? glacier.menu.Item[]

---@param ... glacier.menu.Config
---@return glacier.menu.Menu
function menu.mt:__call(...)
    return Menu:new(...)
end

---@class glacier.menu.MenuDesc
---@field [1] string The item label. Set to an empty string to create a separator.
---@field [2]? glacier.menu.item.SubmitFn|glacier.menu.MenuDesc[] Either the function to call on
---submit, or an array of descriptors for a submenu.

---Automatically create a menu from a simplified descriptor.
---
---@param desc glacier.menu.MenuDesc[]
---@param config? glacier.menu.Config
---@return glacier.menu.Menu
function menu.auto_menu(desc, config)
    config = config or {}
    config.items = nil

    local items = {}
    for _, v in ipairs(desc) do
        local label = v[1]
        local action = v[2]
        local act_type = type(action)

        if label == "" then
            table.insert(items, _item.separator())
        elseif act_type == "function" or act_type == "nil" then
            table.insert(items, _item.simple_item(label, action))
        elseif act_type == "table" then
            local subconfig = require("snowcap.util").deep_copy(config)
            local on_open = function(_)
                return menu.auto_menu(action, subconfig)
            end

            table.insert(items, _item.simple_menu(label, on_open))
        else
            error("Invalid MenuDesc")
        end
    end

    config.items = items
    return Menu:new(config)
end

---@diagnostic disable-next-line:param-type-mismatch
return setmetatable(menu, menu.mt) --[[@as glacier.menu]]
