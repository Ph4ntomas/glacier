local Widget = require("snowcap.widget")
local StdSig = require("snowcap.widget.signal")

local color = require("glacier.misc.color")

local _entry = require("glacier.menu.entry")
local _signal = require("glacier.menu.signal")

---Glacier's Menu module
---The `Menu` class allows creating ContextMenu as Popups.
---
---# Entries
---Each menu is composed of several `Entry` object that are layout as a single column. There
---exists 3 kind of entries:
---- Standard: This are your basic element. Activating one usually triggers a single action then
---close the menu.
---- SubMenu: Hovering or activating these will open a new `Menu` which will be tied to the
---current one.
---- Separator: Use these if you want to display a lines to create section in your `Menu`.
---
---Standard and SubMenu entries do not display anything by themselves. The internally store a
---`Program` to which they calls. Calls to `Program:update` are forwarded if the received
---message doesn't concern the `Entry` itself.
---
---It's up to the nested `Program` to handle calls to `entry::Message::Hover` or
---`entry::Message::Submit`. For convenience, the function `entry::standard` and
---`entry::submenu` takes a callback and wrap it in a suitable `Program`.
---
---# SubMenu
---When a new SubMenu is open, its parent Menu will spawn a `popup` to host it. That popup will
---always be positioned relative to the `Entry` it's linked to. The exact positioning of the
---new popup can be controlled by calling `Menu::submenu_config` on the toplevel `Menu`.
---
---If the toplevel `Menu` was opened via `Menu::popup` and no submenu configuration was set,
---submenus will inherit their parent configuration.
---
---Only one SubMenu may be opened at a time.
---
---# Interacting with the menu
---`Menu` support both mouse, keyboard interaction and programmatic interaction.
---
---When using the mouse, submenu will automatically open when they are being hovered. Standard
---entries requires a click to trigger their action.
---
---Keyboard interaction can be configured by calling `Menu:set_key_config`. When this is used,
---submenu aren't opened automatically on hover.
---
---It's also possible to send messages to the `Menu` directly using the `Handle` object.
---
---@class glacier.widget.menu
---@field mt metatable The module's metatable.
---
---@overload fun(...: glacier.menu.Config): glacier.menu.Menu
local menu = { mt = {} }

----------------------
-- Type Definitions --
----------------------

---@package
---@class glacier.menu.Event
---@field next? {}
---@field prev? {}
---@field submit? {}
---@field mouse_submit? {}
---@field refresh_hover? snowcap.widget.mouse_area.MoveEvent
---@field open_menu? {}
---@field close_submenu? {}
---@field close? {}

---@package
---@class glacier.menu.Message
---@field id number
---@field event glacier.menu.Event
local Message = {}

---@class glacier.menu.style.Separator
---@field fg_color? snowcap.widget.Color
---@field bg_color? snowcap.widget.Color
---@field padding? snowcap.widget.Padding
---@field thickness? number

---@class glacier.menu.style.MenuIndicator
---@field color? snowcap.widget.Color
---@field color_disabled? snowcap.widget.Color
---@field color_selected? snowcap.widget.Color
---@field width? snowcap.widget.Length
---@field height? snowcap.widget.Length

---@class glacier.menu.style.EntryState
---@field fg_color? snowcap.widget.Color
---@field bg_color? snowcap.widget.Color
---@field border? snowcap.widget.Border

---@class glacier.menu.style.Entry: glacier.menu.style.EntryState
---@field selected? glacier.menu.style.EntryState
---@field disabled? glacier.menu.style.EntryState
---@field height? number
---@field padding? snowcap.widget.Padding

---Menu appearance
---@class glacier.menu.Style
---@field bg_color? snowcap.widget.Color
---@field width? snowcap.widget.Length
---@field entry? glacier.menu.style.Entry
---@field menu_indicator? glacier.menu.style.MenuIndicator
---@field separator? glacier.menu.style.Separator
---@field padding? snowcap.widget.Padding
---@field spacing? number
---@field border? snowcap.widget.Border

---@class glacier.menu.PopupConfig
---@field anchor? snowcap.popup.Anchor
---@field gravity? snowcap.popup.Gravity
---@field offset? snowcap.popup.Offset
---@field constraint_adjust? snowcap.popup.ConstraintsAdjust
---@field no_grab? boolean
---@field no_replace? boolean

---Menu's keyboard configuration
---@class glacier.menu.KeyConfig
---@field next? snowcap.Key[]
---@field prev? snowcap.Key[]
---@field submit? snowcap.Key[]
---@field open_menu? snowcap.Key[]
---@field close_menu? snowcap.Key[]
---@field close? snowcap.Key[]

---@class glacier.menu.Config
---@field style? glacier.menu.Style
---@field key_config? glacier.menu.KeyConfig
---@field submenu_config? glacier.menu.PopupConfig
---@field entries glacier.menu.Entry[]

---@class glacier.menu.Submenu
---@field handle glacier.menu.Handle
---@field sub_close_signal snowcap.signal.SignalHandle
---@field close_signal snowcap.signal.SignalHandle

---@class glacier.menu.Menu: snowcap.widget.Program
---@field private _entries glacier.menu.Entry[]
---@field private _style glacier.menu.Style
---@field private _key_config glacier.menu.KeyConfig
---
---@field private _selected integer?
---@field private _hovered integer?
---
---@field private _submenu_config? glacier.menu.PopupConfig
---@field private _submenu glacier.menu.Submenu
local Menu = setmetatable({}, { __index = require("snowcap.widget.base").Base })

---@class glacier.menu.Handle
---@field private _id number
---@field private _handle snowcap.popup.PopupHandle
local Handle = {}

----------------------
-- Module functions --
----------------------

---Menu's default appearance.
---
---@param style? glacier.menu.Style
---@return glacier.menu.Style
function menu.default_style(style)
    ---@type glacier.menu.Style
    local ret = {
        bg_color = color.from_hex("#2b2b2b"),
        width = Widget.length.Fixed(250.0),

        entry = {
            fg_color = color.from_hex("#d7d7d7"),
            height = 24.0,
            padding = {
                left = 2.0,
                right = 2.0,
            },
            selected = {
                bg_color = color.from_hex("#6B1ABC"),
            },
            disabled = {
                fg_color = color.from_hex("#5B5B5B"),
            },
        },
        menu_indicator = {
            color = color.from_hex("#7b7b7b"),
            width = Widget.length.Fixed(12.0),
            height = Widget.length.Fixed(12.0),
        },
        separator = {
            fg_color = color.from_hex("#131313"),
            padding = {
                top = 3.0,
                bottom = 3.0,
                left = 8.0,
                right = 8.0,
            },
            thickness = 1.0,
        },

        spacing = 1.0,
    }

    return require("glacier.utils").merge_table(ret, style)
end

---Menu's default render view
---
---@param entries snowcap.widget.WidgetDef[]
---@param style glacier.menu.Style)
---@return snowcap.widget.WidgetDef
function menu.default_view(entries, style)
    return Widget.container({
        child = Widget.column({
            children = entries,
        }),
        width = style.width,
        padding = style.padding,
        style = {
            background = style.bg_color and Widget.background.Color(style.bg_color) or nil,
            border = style.border,
        },
    })
end

---Menu's default keyboard handlers
---
---@param id number
---@param key_event snowcap.input.KeyEvent,
---@param key_config glacier.menu.KeyConfig,
---@param weak_signaler glacier.utils.Weak<snowcap.signal.Signaler>
function menu.default_keyboard_handler(id, key_event, key_config, weak_signaler)
    if key_event.captured or not key_event.pressed then
        return
    end

    local signaler = weak_signaler:get()

    if not signaler then
        return
    end

    local contains = function(keys)
        for _, key in ipairs(keys) do
            if key == key_event.key then
                return true
            end
        end
        return false
    end

    local msg
    if contains(key_config.close) then
        msg = Message.close(id)
    elseif contains(key_config.next) then
        msg = Message.next(id)
    elseif contains(key_config.prev) then
        msg = Message.prev(id)
    elseif contains(key_config.submit) then
        msg = Message.submit(id)
    elseif contains(key_config.open_menu) then
        msg = Message.open_menu(id)
    elseif contains(key_config.close_menu) then
        signaler:emit(_signal.REQUEST_SUBMENU_CLOSE)
        return
    end

    if msg then
        signaler:emit(require("snowcap.widget.signal").send_message, msg)
    end
end

---Menu's default keyboard configuration.
---@param config? glacier.menu.KeyConfig
---@return glacier.menu.KeyConfig
function menu.default_key_config(config)
    local Key = require("snowcap.input.keys")
    config = config or {}

    ---@type glacier.menu.KeyConfig
    local ret = {
        next = config.next or { Key.Down },
        prev = config.prev or { Key.Up },
        submit = config.submit or { Key.Return },
        open_menu = config.open_menu or { Key.Right },
        close_menu = config.close_menu or { Key.Left },
        close = config.close or { Key.Escape },
    }

    return require("glacier.utils").merge_table(ret, config)
end

-----------------------
-- Message functions --
-----------------------

---@package
---
---@param id integer
---@return glacier.menu.Message
function Message.next(id)
    return {
        id = id,
        event = {
            next = {},
        },
    }
end

---@package
---
---@param id integer
---@return glacier.menu.Message
function Message.prev(id)
    ---@type glacier.menu.Message
    return {
        id = id,
        event = {
            prev = {},
        },
    }
end

---@package
---
---@param id integer
---@return glacier.menu.Message
function Message.submit(id)
    ---@type glacier.menu.Message
    return {
        id = id,
        event = {
            submit = {},
        },
    }
end

---@package
---
---@param id integer
---@return glacier.menu.Message
function Message.mouse_submit(id)
    ---@type glacier.menu.Message
    return {
        id = id,
        event = {
            mouse_submit = {},
        },
    }
end

---@package
---
---@param id integer
---@param point snowcap.widget.mouse_area.MoveEvent
---@return glacier.menu.Message
function Message.refresh_hover(id, point)
    ---@type glacier.menu.Message
    return {
        id = id,
        event = {
            refresh_hover = point,
        },
    }
end

---@package
---
---@param id integer
---@return glacier.menu.Message
function Message.open_menu(id)
    ---@type glacier.menu.Message
    return {
        id = id,
        event = {
            open_menu = {},
        },
    }
end

---@package
---
---@param id integer
---@return glacier.menu.Message
function Message.close_submenu(id)
    ---@type glacier.menu.Message
    return {
        id = id,
        event = {
            close_submenu = {},
        },
    }
end

---@package
---
---@param id integer
---@return glacier.menu.Message
function Message.close(id)
    ---@type glacier.menu.Message
    return {
        id = id,
        event = {
            close = {},
        },
    }
end

---------------------------
-- Handle public methods --
---------------------------

---Close the `Menu`.
function Handle:close()
    self._handle:close()
end

---Focus the next entry.
function Handle:next()
    self:send_message(Message.next(self._id))
end

---Focus the previous entry.
function Handle:prev()
    self:send_message(Message.prev(self._id))
end

---Activate the focus entry.
function Handle:submit()
    self:send_message(Message.submit(self._id))
end

---Send a message to the Menu
---@param msg any
function Handle:send_message(msg)
    self._handle:send_message(msg)
end

----------------------------
-- Handle private methods --
----------------------------

---@private
---
---@return string
function Handle:__tostring()
    return ("<menu::Handle#%d>"):format(self._id)
end

---------------------
-- Handle Lifetime --
---------------------

---@package
---Initialize a Handle
---
---@param handle glacier.menu.Handle
function Handle.new(handle)
    return setmetatable(handle, { __index = Handle, __tostring = Handle.__tostring })
end

-------------------------
-- Menu public methods --
-------------------------

---Set the Menu key_config
---
---@param key_config glacier.menu.KeyConfig
function Menu:set_key_config(key_config)
    self._key_config = key_config
end

---@param config glacier.menu.PopupConfig
function Menu:set_submenu_config(config)
    self._submenu_config = config
end

---Open the Menu as a popup.
---
---@param parent snowcap.popup.ParentHandle
---@param position snowcap.popup.Position
---@param config glacier.menu.PopupConfig
---@return glacier.menu.Handle?
function Menu:popup(parent, position, config)
    if not self._submenu_config then
        self._submenu_config = require("snowcap.util").deep_copy(config)
    end

    local popup_handle = require("snowcap.popup").new_widget({
        program = self,
        parent = parent,
        position = position,
        anchor = config.anchor,
        constraints_adjust = config.constraint_adjust,
        gravity = config.gravity,
        offset = config.offset,
        no_grab = config.no_grab,
        no_replace = config.no_replace,
    })

    if not popup_handle then
        return nil
    end

    local id = self:id()
    local signaler = require("glacier.utils").weak(self:signaler())
    local key_config = self._key_config
    popup_handle:on_key_event(function(_, key_event)
        menu.default_keyboard_handler(id, key_event, key_config, signaler)
    end)

    return Handle.new({
        _id = id,
        _handle = popup_handle,
    })
end

--------------------------
-- Menu private methods --
--------------------------

---@private
---
---@param id integer
---@return string
function Menu:make_entry_id(id)
    return ("menu#%d-%d"):format(self:id(), id)
end

---@private
---
---@param entry glacier.menu.Entry
---@param id string
---@param selected boolean
---@return snowcap.widget.WidgetDef?
function Menu:view_entry(entry, id, selected)
    if entry:is_separator() then
        return _entry.separator_view(self._style.separator)
    end

    local view = Widget.container({
        child = entry:view() or Widget.row({ children = {} }),
        width = Widget.length.Fill,
    })

    local menu_indicator
    if entry:is_menu() then
        menu_indicator =
            _entry.menu_indicator_view(self._style.menu_indicator, entry:is_disabled(), selected)
    end

    local deep_copy = require("snowcap.util").deep_copy
    local merge_table = require("glacier.utils").merge_table
    ---@type glacier.menu.style.EntryState
    local style = deep_copy({
        fg_color = self._style.entry.fg_color,
        bg_color = self._style.entry.bg_color,
        border = self._style.entry.border,
    })

    if entry:is_disabled() and self._style.entry.disabled then
        style = merge_table(style, self._style.entry.disabled)
    elseif not entry:is_disabled() and selected and self._style.entry.selected then
        style = merge_table(style, self._style.entry.selected)
    end

    local row = Widget.row({
        children = { view, menu_indicator },
        clip = true,
        item_alignment = Widget.alignment.CENTER,
        height = Widget.length.Fill,
        width = Widget.length.Fill,
    })

    return Widget.container({
        child = row,
        id = id,
        height = Widget.length.Fixed(self._style.entry.height),
        width = Widget.length.Fill,
        clip = true,
        padding = self._style.entry.padding,
        style = {
            text_color = style.fg_color,
            background = style.bg_color and Widget.background.Color(style.bg_color) or nil,
            border = style.border,
        },
    })
end

---@private
---
---@param point {x: number, y: number}
---@return integer?
function Menu:find_hovered(point)
    local top = self._style.padding and self._style.padding.top
    top = top or 0.0

    local prev = top
    for i, entry in ipairs(self._entries) do
        local next
        if entry:is_separator() then
            local p_top = self._style.separator.padding and self._style.separator.padding.top
            p_top = p_top or 0.0

            local p_bot = self._style.separator.padding and self._style.separator.padding.bottom
            p_bot = p_bot or 0.0

            next = prev + self._style.separator.thickness + p_top + p_bot
        else
            next = prev + self._style.entry.height
        end

        if not entry:is_disabled() then
            if point.y >= prev and point.y < next then
                return i
            end
        end

        prev = next
    end

    return nil
end

---@private
---
---@return integer?
function Menu:find_next()
    if #self._entries == 0 then
        return
    end

    if self._selected then
        local start = self._selected + 1

        for idx = start, #self._entries do
            if not self._entries[idx]:is_disabled() then
                return idx
            end
        end
    end

    for i, entry in ipairs(self._entries) do
        if not entry:is_disabled() then
            return i
        end
    end

    return nil
end

---@private
---
---@return integer?
function Menu:find_prev()
    if #self._entries == 0 then
        return nil
    end

    if self._selected then
        local start = self._selected - 1

        for idx = start, 1, -1 do
            if not self._entries[idx]:is_disabled() then
                return idx
            end
        end
    end

    local start = #self._entries
    for idx = start, 1, -1 do
        if not self._entries[idx]:is_disabled() then
            return idx
        end
    end

    return nil
end

---@private
---Get the selected entry.
---
---@return glacier.menu.Entry?
function Menu:get_selected()
    return self._selected and self._entries[self._selected] or nil
end

---@private
---Select an entry by id.
---
---@param id integer
---@param hover boolean
function Menu:select(id, hover)
    if id == self._selected then
        return
    end

    self:close_menu()
    self._selected = id

    local entry = self:get_selected()

    if not entry then
        return
    end

    entry:update(_entry.Message.hover())

    if hover and entry:is_menu() then
        self:open_entry()
    end
end

---@private
---Submit the selected entry
---
---@return boolean # True if the menu should be closed as a result.
function Menu:submit_entry()
    local entry = self:get_selected()
    if not entry or entry:is_disabled() then
        return false
    end

    if entry:is_menu() then
        self:open_entry()
        return false
    end

    entry:update(_entry.Message.submit())

    return entry:should_close_on_submit()
end

---@private
---
---Open the selected entry.
function Menu:open_entry()
    local entry = self:get_selected()
    if not entry or entry:is_disabled() or not entry:is_menu() then
        return
    end

    local submenu = entry:open_menu()
    if not submenu then
        return
    end

    self:open_submenu(submenu)
end

---@private
---
---Close the submenu if opened.
function Menu:close_menu()
    local submenu = self._submenu
    self._submenu = nil

    if not submenu then
        return
    end

    submenu.close_signal:disconnect()
    submenu.sub_close_signal:disconnect()

    submenu.handle:close()
end

---@private
---
---Open the submenu.
---@param submenu glacier.menu.Menu
function Menu:open_submenu(submenu)
    local entry = self:get_selected()
    if not entry or entry:is_disabled() or not entry:is_menu() then
        return
    end

    if not self._handle then
        return
    end

    self:close_menu()

    local id = self._selected --[[@as integer]]
    local position = require("snowcap.popup").position.AtWidget(self:make_entry_id(id))
    local deep_copy = require("snowcap.util").deep_copy

    local config = deep_copy(self._submenu_config)
    assert(config, "Missing submenu config.")

    local sub_close_signal = submenu:connect(_signal.REQUEST_SUBMENU_CLOSE, function()
        self:emit(StdSig.send_message, Message.close_submenu(self:id()))
    end)
    local close_signal = submenu:connect(StdSig.request_close, function()
        self:emit(StdSig.send_message, Message.close(self:id()))
    end)

    submenu:set_key_config(deep_copy(self._key_config))

    local menu_handle = submenu:popup(self._handle:as_parent(), position, config)
    if menu_handle == nil then
        sub_close_signal:disconnect()
        close_signal:disconnect()
        return
    end

    self._submenu = {
        handle = menu_handle,
        sub_close_signal = sub_close_signal,
        close_signal = close_signal,
    }
end

---@private
---
---@param entries glacier.menu.Entry[]
function Menu:refresh_entries(entries)
    for _, entry in ipairs(self._entries) do
        entry:event({
            closing = {},
        })
    end

    if self._handle then
        for _, entry in ipairs(entries) do
            entry:event({
                created = self._handle,
            })

            if not entry:is_separator() then
                self:register_child(entry)
            end
        end
    end

    self._entries = entries
end

---@private
---
---@param msg any|glacier.menu.Message
---@return glacier.menu.Event?
function Menu:get_message_event(msg)
    if msg.id == self:id() then
        return msg.event
    end

    return nil
end

---@private
function Menu:__tostring()
    return ("<Menu#%d>"):format(self:id())
end

---------------------------------
-- impl snowcap.widget.Program --
---------------------------------

---Creates a widget definition for display by Snowcap.
---
---A widget may return nil to notify its parent program that it has
---nothing to display. It's up to the parent to decide whether to display a
---placeholder or to remove the widget from the tree.
---@return snowcap.widget.WidgetDef?
function Menu:view()
    local entries = {}

    for id, entry in ipairs(self._entries) do
        local selected = self._selected == id
        local entry_id = self:make_entry_id(id)

        local view = self:view_entry(entry, entry_id, selected)
        if view then
            table.insert(entries, view)
        end
    end

    return Widget.container({
        child = Widget.mouse_area({
            child = Widget.column({
                children = entries,
            }),
            on_move = function(point)
                return Message.refresh_hover(self:id(), point)
            end,
            on_press = Message.mouse_submit(self:id()),
        }),
        width = self._style.width,
        style = {
            background = self._style.bg_color and Widget.background.Color(self._style.bg_color)
                or nil,
        },
    })
end

---Updates this widget program with the received message.
---@param msg any|glacier.menu.Message
function Menu:update(msg)
    local closing = false

    local event = self:get_message_event(msg)

    if not event then
        if self._submenu and self._submenu.handle then
            self._submenu.handle:send_message(msg)
        end

        for _, entry in ipairs(self._entries) do
            entry:update(msg)
        end

        return
    end

    if event.refresh_hover then
        self._hovered = self:find_hovered(event.refresh_hover)
        if self._hovered then
            self:select(self._hovered, true)
        end
    elseif event.next then
        local id = self:find_next()
        if id then
            self:select(id, false)
        end
    elseif event.prev then
        local id = self:find_prev()
        if id then
            self:select(id, false)
        end
    elseif event.submit then
        closing = self:submit_entry()
    elseif event.mouse_submit then
        if self._hovered then
            self._selected = self._hovered
            closing = self:submit_entry()
        end
    elseif event.open_menu then
        self:open_entry()
    elseif event.close_submenu then
        self:close_menu()
    elseif event.close then
        closing = true
    end

    if closing then
        self:emit(StdSig.request_close)
    end
end

---Called when a surface has been created with this program.
---
---A surface handle is provided to allow the program to manupulate
---the surface. This handle should be passed to any child programs
---to allow them to use it as well.
---
---@param event snowcap.widget.SurfaceEvent
function Menu:event(event)
    if event.created then
        self._handle = event.created

        local entries = self._entries
        self._entries = {}

        self:refresh_entries(entries)
        return
    elseif event.closing then
        self:emit(StdSig.closed)

        self._handle = nil
    end

    for _, entry in ipairs(self._entries) do
        entry:event(event)
    end
end

-----------
-- Other --
-----------

---Create a new menu
---
---@param config glacier.menu.Config
---@return glacier.menu.Menu
function Menu:new(config)
    config = config or {}
    config.style = config.style or menu.default_style()
    config.key_config = config.key_config or menu.default_key_config()

    local base = require("snowcap.widget.base").Base.new()
    local ret = setmetatable(base, { __index = Menu, __tostring = Menu.__tostring }) --[[@as glacier.menu.Menu]]

    ret._entries = config.entries or {}
    ret._style = config.style
    ret._key_config = config.key_config

    ret._selected = nil
    ret._hovered = nil

    ret._submenu_config = config.submenu_config
    ret._submenu = nil

    return ret
end

---Create a new menu
---
---@param ... glacier.menu.Config
---@return glacier.menu.Menu
function menu.mt:__call(...)
    return Menu:new(...)
end

menu.signal = _signal
menu.entry = _entry
menu.Menu = Menu

---@diagnostic disable-next-line: param-type-mismatch
return setmetatable(menu, menu.mt) --[[@as glacier.widget.menu]]
