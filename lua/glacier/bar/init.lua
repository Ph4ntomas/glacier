local Layer = require("snowcap.layer")
local Widget = require("snowcap.widget")

local color = require("glacier.misc.color")

---Glacier's bar module.
---
---The bar is split into 3 area (`first`, `center` and `last`). By default,
---the bar sits at the top of the screen and renders each areas left to right,
---using the following layout:
--- - first: The area shrink to fit its content, which is left-aligned.
--- - center: The area fills the space. The content is left-aligned.
--- - right: The area shrink to fit its content, which is right-aligned.
---```
---| first     |         center        |     last |
---```
---
---## Rendering
---When the bar's view is called, the call first forwarded to every child. Then,
---the view functions for each area are called with the respective children widgets.
---Finally, the bar put each area in a container.
---
---@class glacier.bar
---@field mt metatable The module's metatable
---
---@overload fun(...: glacier.bar.Config): glacier.bar.Bar
local _bar = { mt = {} }

----------------------
-- Type definitions --
----------------------

---Override a block view.
---@alias glacier.bar.ViewFn fun(children: snowcap.widget.WidgetDef[], style: glacier.bar.Style): snowcap.widget.WidgetDef?

---@class glacier.bar.Style
---@field pixels? integer Dimension of the bar, in pixel.
---@field padding? snowcap.widget.Padding Bar padding.
---@field bg_color? snowcap.widget.Color Bar background color.
---@field border? snowcap.widget.Border Bar's border.
---@field spacing? number Spacing between elements.
---@field first_spacing? number Spacing between first block.
---@field center_spacing? number Spacing between center block.
---@field last_spacing? number Spacing between last block.

---Glacier's Bar
---
---See module-level documentation for more informations.
---
---@class glacier.bar.Bar: snowcap.widget.Program
---@field handle snowcap.widget.SurfaceHandle?
---
---@field style glacier.bar.Style
---
---@field first snowcap.widget.Program[]
---@field center snowcap.widget.Program[]
---@field last snowcap.widget.Program[]
---
---@field first_view glacier.bar.ViewFn
---@field center_view glacier.bar.ViewFn
---@field last_view glacier.bar.ViewFn
local Bar = {}
setmetatable(Bar, { __index = require("snowcap.widget.base").Base })

---@class glacier.bar.Handle
---@field handle snowcap.layer.LayerHandle
local Handle = {}

---Bar's configuration.
---
---@class glacier.bar.Config
---@field style? glacier.bar.Style Bar's style
---
---@field first? snowcap.widget.Program[] Array of Program for the first area.
---@field center? snowcap.widget.Program[] Array of Program for the center area.
---@field last? snowcap.widget.Program[] Array of Program for the last area.
---
---@field first_view? glacier.bar.ViewFn First area render function.
---@field center_view? glacier.bar.ViewFn Center area render function.
---@field last_view? glacier.bar.ViewFn Last area render function.
local Config = {}

---------------------------
-- Default configuration --
---------------------------

---Bars' default style.
---
---@return glacier.bar.Style
function _bar.default_style()
    ---@type glacier.bar.Style
    return {
        pixels = 24,
        padding = {
            top = 8,
            bottom = 8,
            left = 8,
            right = 8,
        },
        bg_color = color.from_hex("#1a1a1a"),
    }
end

---Default view for the Bar's first area.
---
---@param children snowcap.widget.WidgetDef
---@param style glacier.bar.Style
---@return snowcap.widget.WidgetDef
function _bar.default_first_view(children, style)
    return Widget.row({
        children = children,
        height = Widget.length.Fill,
        width = Widget.length.Shrink,
        item_alignment = Widget.alignment.START,
        spacing = style.first_spacing or style.spacing,
    })
end

---Default view for the Bar's center area.
---
---@param children snowcap.widget.WidgetDef
---@param style glacier.bar.Style
---@return snowcap.widget.WidgetDef
function _bar.default_center_view(children, style)
    return Widget.row({
        children = children,
        height = Widget.length.Fill,
        width = Widget.length.Fill,
        item_alignment = Widget.alignment.START,
        spacing = style.center_spacing or style.spacing,
    })
end

---Default view for the Bar's last area.
---
---@param children snowcap.widget.WidgetDef
---@param style glacier.bar.Style
---@return snowcap.widget.WidgetDef
function _bar.default_last_view(children, style)
    return Widget.row({
        children = children,
        height = Widget.length.Fill,
        width = Widget.length.Shrink,
        item_alignment = Widget.alignment.START,
        spacing = style.last_spacing or style.spacing,
    })
end

--------------------------
-- Bar's public methods --
--------------------------

---Create a layer to display the `Bar` as a standalone program.
---
---@return glacier.bar.Handle?
function Bar:show()
    local handle = Layer.new_widget({
        program = self,
        anchor = Layer.anchor.TOP,
        keyboard_interactivity = Layer.keyboard_interactivity.NONE,
        exclusive_zone = self:get_exclusive_size(),
        layer = Layer.zlayer.TOP,
    })

    if not handle then
        return
    end

    return Handle.new(handle)
end

---------------------------
-- Bar's private methods --
---------------------------

---@private
---
---Compute the bar's exclusive size.
---
---@return number
function Bar:get_exclusive_size()
    local padding = self.style.padding or { top = 0, bottom = 0, left = 0, right = 0 }
    local padding_sz = padding.top + padding.bottom

    local pixels = self.style.pixels or 0

    return math.max(padding_sz + pixels, 1)
end

---@private
---
---Apply a function on every children.
---@param callback fun(child: snowcap.widget.Program)
function Bar:foreach_children(callback)
    for _, child in ipairs(self.first) do
        callback(child)
    end

    for _, child in ipairs(self.center) do
        callback(child)
    end

    for _, child in ipairs(self.last) do
        callback(child)
    end
end

---@private
---
---Render every children in a children array.
---@param children snowcap.widget.Program[]
---@return snowcap.widget.WidgetDef[]
function Bar:view_children(children)
    local ret = {}

    for _, child in ipairs(children) do
        local tmp = child:view()

        if tmp ~= nil then
            table.insert(ret, tmp)
        end
    end

    return ret
end

--------------------------------
-- impl snowcap.widget.Progam --
--------------------------------

---Creates a widget definition for display by Snowcap.
---
---A widget may return nil to notify its parent program that it has
---nothing to display. It's up to the parent to decide whether to display a
---placeholder or to remove the widget from the tree.
---@return snowcap.widget.WidgetDef?
function Bar:view()
    local first = self:view_children(self.first)
    local center = self:view_children(self.center)
    local last = self:view_children(self.last)

    local first_view_fn = self.first_view or _bar.default_first_view
    local center_view_fn = self.center_view or _bar.default_center_view
    local last_view_fn = self.last_view or _bar.default_last_view

    local first_view = first_view_fn(first, self.style)
    local center_view = center_view_fn(center, self.style)
    local last_view = last_view_fn(last, self.style)

    local view = Widget.container({
        child = Widget.row({
            children = { first_view, center_view, last_view },
            spacing = self.style.spacing,
            item_alignment = Widget.alignment.START,
            height = Widget.length.Fixed(self.style.pixels or 0),
        }),
        width = Widget.length.Fill,
        halign = Widget.alignment.START,
        valign = Widget.alignment.START,
        padding = self.style.padding,
        clip = true,
        style = {
            background = Widget.background.Color(self.style.bg_color),
            border = self.style.border,
        },
    })

    return view
end

---Updates this widget program with the received message.
---@param msg any
function Bar:update(msg)
    self:foreach_children(function(c)
        c:update(msg)
    end)
end

---Called when a surface has been created with this program.
---
---A surface handle is provided to allow the program to manupulate
---the surface. This handle should be passed to any child programs
---to allow them to use it as well.
---
---@param event snowcap.widget.SurfaceEvent
function Bar:event(event)
    local signal = require("snowcap.widget.signal")

    if event.created then
        self.handle = event.created

        self:foreach_children(function(c)
            self:register_child(c)
        end)
    elseif event.closing then
        self:emit(signal.closed)
    end

    self:foreach_children(function(c)
        c:event(event)
    end)
end

---------------------------
-- Handle public methods --
---------------------------

---Create a new Handle
---
---@param handle snowcap.layer.LayerHandle
---
---@return glacier.bar.Handle
function Handle.new(handle)
    local _handle = setmetatable({ handle = handle }, { __index = Handle })

    return _handle
end

---Request keyboard focus for the `Bar`
function Handle:focus()
    self.handle:update({
        keyboard_interactivity = Layer.keyboard_interactivity.EXCLUSIVE,
    })
end

---Remove keyboard focus for the `Bar`
function Handle:unfocus()
    self.handle:update({
        keyboard_interactivity = Layer.keyboard_interactivity.NONE,
    })
end

---Sends an arbitrary Message
---
---@param msg any
function Handle:send_message(msg)
    self.handle.send_message(msg)
end

---Sets the keyboard event handler for this a `Bar`.
---
---@param on_event fun(handle: glacier.bar.Handle, event: snowcap.input.KeyEvent)
function Handle:on_key_event(on_event)
    self.handle:on_key_event(function(handle, event)
        on_event(Handle.new(handle), event)
    end)
end

-----------
-- Other --
-----------

---Create a new `Bar`.
---@param config glacier.bar.Config
function Bar:new(config)
    config = config or {}
    config.style = require("glacier.utils").merge_table(config.style or {}, _bar.default_style())

    local base = require("snowcap.widget.base").Base.new()
    local bar = setmetatable(base, { __index = Bar, __tostring = Bar.__tostring }) --[[@as glacier.bar.Bar]]

    bar.style = config.style

    bar.first = config.first or {}
    bar.center = config.center or {}
    bar.last = config.last or {}

    bar.first_view = config.first_view
    bar.center_view = config.center_view
    bar.last_view = config.last_view

    return bar
end

function Bar:__tostring()
    return ("<Bar#%d>"):format(self:id())
end

_bar.Bar = Bar

---Create a new Bar.
---@param ... glacier.bar.Config
---@return glacier.bar.Bar
function _bar.mt:__call(...)
    return Bar:new(...)
end

---@diagnostic disable-next-line: param-type-mismatch
return setmetatable(_bar, _bar.mt) --[[@as glacier.bar]]
