local Widget = require("snowcap.widget")

local icons = require("glacier.misc.icons")

---@class glacier.menu.entry
local entry = {}

----------------------
-- Type Definitions --
----------------------

---@alias glacier.menu.entry.OpenMenuCallback fun(): glacier.menu.Menu

---@alias glacier.menu.entry.SubmitCallback fun()

---@class glacier.menu.entry.Event
---@field hover? {}
---@field submit? {}
---@field enable? string
---@field disable? string

---@class glacier.menu.entry.Message
---@field tag string
---@field event glacier.menu.entry.Event
local Message = {}

---@class glacier.menu.entry.Config
---@field id? string
---@field disabled? boolean
---@field close_on_submit? boolean
---
---@field package program? snowcap.widget.Program
---@field package on_submit? glacier.menu.entry.SubmitCallback
---@field package on_open_menu? glacier.menu.entry.OpenMenuCallback
---@field package is_menu? boolean

---@class glacier.menu.entry.WithMenu: snowcap.widget.Program
---@field open_menu fun(self: self): glacier.menu.Menu?

---@class glacier.menu.Entry: snowcap.widget.Program
---@field private _id? string
---@field private _program? snowcap.widget.Program|glacier.menu.entry.WithMenu
---@field private _is_menu boolean
---@field private _disabled boolean
---@field private _close_on_submit boolean
---@field private _on_submit? glacier.menu.entry.SubmitCallback
---@field private _on_open_menu? glacier.menu.entry.OpenMenuCallback
local Entry = setmetatable({}, { __index = require("snowcap.widget.base").Base })

----------------------
-- Module functions --
----------------------

---@param style glacier.menu.style.Separator
function entry.separator_view(style)
    local separator = Widget.container({
        child = Widget.column({ children = {} }),
        width = Widget.length.Fill,
        height = Widget.length.Fixed(style.thickness),
        style = {
            background = style.bg_color and Widget.background.Color(style.bg_color) or nil,
            border = {
                color = style.fg_color,
                width = style.thickness,
            },
        },
    })

    return Widget.container({
        child = separator,
        padding = style.padding,
    })
end

---@param style glacier.menu.style.MenuIndicator
---@param disabled boolean
---@param selected boolean
function entry.menu_indicator_view(style, disabled, selected)
    local fg_color = style.color

    if disabled and style.color_disabled then
        fg_color = style.color_disabled
    elseif selected and style.color_selected then
        fg_color = style.color_selected
    end

    local icon_handle = icons.menu.menu_indicator():to_image_handle(fg_color)
    local icon = Widget.Image({
        width = style.width,
        height = style.height,
        content_fit = Widget.image.content_fit.SCALE_DOWN,
        handle = icon_handle,
    })

    return icon
end

-----------------------
-- Message functions --
-----------------------

---Message sent to entries when they start being hovered.
---
---@return glacier.menu.entry.Message
function Message.hover()
    ---@type glacier.menu.entry.Message
    return {
        tag = entry.MESSAGE_TAG,
        event = {
            hover = {},
        },
    }
end

---Message sent to entries when they are submitted.
---
---@return glacier.menu.entry.Message
function Message.submit()
    ---@type glacier.menu.entry.Message
    return {
        tag = entry.MESSAGE_TAG,
        event = {
            submit = {},
        },
    }
end

---Message sent to entries to change their enable state.
---
---@param id string
---@return glacier.menu.entry.Message
function Message.enable(id)
    ---@type glacier.menu.entry.Message
    return {
        tag = entry.MESSAGE_TAG,
        event = {
            enable = id,
        },
    }
end

---Message sent to entries to change their enable state.
---
---@param id string
---@return glacier.menu.entry.Message
function Message.disable(id)
    ---@type glacier.menu.entry.Message
    return {
        tag = entry.MESSAGE_TAG,
        event = {
            disable = id,
        },
    }
end

--------------------------
-- Entry public methods --
--------------------------

---Check if this Entry is a menu.
---
---@return boolean
function Entry:is_menu()
    return self._program ~= nil and self._is_menu
end

---Check if this Entry is a standard entry.
---
function Entry:is_standard()
    return self._program ~= nil and not self._is_menu
end

---Check if this Entry is a separator.
---
function Entry:is_separator()
    return self._program == nil
end

---Check whether the entry is disabled.
---
---@return boolean
function Entry:is_disabled()
    return self._disabled
end

function Entry:should_close_on_submit()
    return self:is_standard() and self._close_on_submit
end

function Entry:open_menu()
    if not self._is_menu or self._disabled then
        return nil
    end

    if self._on_open_menu then
        return self._on_open_menu()
    elseif type(self._program.open_menu) == "function" then
        local child = self._program --[[@as glacier.menu.entry.WithMenu]]
        return child:open_menu()
    end

    return nil
end

---------------------------
-- Entry private methods --
---------------------------

------------------------------
-- impl snowcap.widget.Base --
------------------------------

---Gets the widget's signaler
---
---@return snowcap.signal.Signaler
function Entry:signaler()
    if self._program then
        return self._program:signaler()
    else
        error("Separator don't have a signaler.")
    end
end

---Connects a callback to a specific signal.
---
---@param name string The name of the signal you're connecting to.
---@return snowcap.signal.SignalHandle
function Entry:connect(name, callback)
    if self._program then
        return self._program:connect(name, callback)
    else
        error("Can't connect to separators")
    end
end

---Emits a signal.
---
---@param name string Signal to emit
---@param ... any Parameter to sent to the callbacks
function Entry:emit(name, ...)
    if self._program then
        self._program:emit(name, ...)
    end
end

---Disconnects a given callback.
---
---@param handle snowcap.signal.SignalHandle Handle to the callback to disconnect.
function Entry:disconnect(handle)
    if self._program then
        self._program:disconnect(handle)
    end
end

---Disconnects all signal handlers.
function Entry:disconnect_all()
    if self._program then
        self._program:disconnect_all()
    end
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
function Entry:view()
    if self._program then
        return self._program:view()
    end
end

---Updates this widget program with the received message.
---@param msg any|glacier.menu.entry.Message
function Entry:update(msg)
    local is_standard = self:is_standard()

    if self._program then
        if msg.tag ~= entry.MESSAGE_TAG then
            self._program:update(msg)
            return
        end

        ---@cast msg glacier.menu.entry.Message
        if is_standard and msg.event.submit then
            if self._on_submit then
                self._on_submit()
                return
            else
                self._program:update(msg)
            end
        elseif msg.event.hover then
            self._program:update(msg)
        elseif msg.event.enable and self._id == msg.event.enable then
            self._disabled = false
        elseif msg.event.disable and self._id == msg.event.disable then
            self._disabled = true
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
function Entry:event(event)
    if self._program then
        return self._program:event(event)
    end
end

-----------
-- Other --
-----------

---@package
---@param config? glacier.menu.entry.Config
---@return glacier.menu.Entry
function Entry:new(config)
    local base = require("snowcap.widget.base").Base.new()
    local ret = setmetatable(base, { __index = Entry }) --[[@as glacier.menu.Entry]]

    if config then
        ret._program = config.program
        ret._id = config.id
        ret._is_menu = config.is_menu
        ret._disabled = config.disabled

        ret._close_on_submit = config.close_on_submit
        ret._on_open_menu = config.on_open_menu
        ret._on_submit = config.on_submit
    else
        ret._disabled = true
        ret._close_on_submit = false
    end

    return ret
end

---@param child snowcap.widget.Program
---@param config? glacier.menu.entry.Config|fun()
---@param on_submit? fun()
---@return glacier.menu.Entry
function entry.standard(child, config, on_submit)
    if type(config) == "function" then
        on_submit = config
        config = nil
    end

    config = config or {}

    if config.disabled == nil then
        config.disabled = false
    end

    if config.close_on_submit == nil then
        config.close_on_submit = true
    end

    config.program = child
    config.is_menu = false
    config.on_submit = on_submit
    config.on_open_menu = nil

    return Entry:new(config)
end

---@param child snowcap.widget.Program|glacier.menu.entry.WithMenu
---@param config? glacier.menu.entry.Config|fun(): glacier.menu.Menu
---@param on_open_menu? fun(): glacier.menu.Menu
---@return glacier.menu.Entry
function entry.menu(child, config, on_open_menu)
    if type(config) == "function" then
        on_open_menu = config
        config = nil
    end

    config = config or {}
    config.disabled = config.disabled ~= nil and config.disabled or false
    config.close_on_submit = false

    config.program = child
    config.is_menu = true
    config.on_open_menu = on_open_menu
    config.on_submit = nil

    if not config.on_open_menu and not child.open_menu then
        error("entry.menu requires a way to open the menu.")
    end

    return Entry:new(config)
end

---@return glacier.menu.Entry
function entry.separator()
    return Entry:new()
end

entry.MESSAGE_TAG = "glacier::menu::EntryTag"

entry.Message = Message

return entry
