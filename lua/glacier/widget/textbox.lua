local Widget = require("snowcap.widget")
local Log = require("snowcap.log")
local StdSig = require("snowcap.widget.signal")
local Signal = require("snowcap.signal")

---glacier.widget.textbox module.
---
---@class glacier.widget.textbox
---@field mt metatable The module metatable.
---
---@overload fun(...: glacier.widget.textbox.Config): glacier.widget.TextBox
local textbox = { mt = {} }

----------------------
-- Type Definitions --
----------------------

---Function called to render the widget.
---@alias glacier.widget.textbox.ViewFn fun(text: string, style: glacier.widget.textbox.Style?): snowcap.widget.WidgetDef

---Function to generate a style based on the TextBox content
---@alias glacier.widget.textbox.StyleFn fun(text: string): glacier.widget.textbox.Style

---Signals emitted by TextBox
---@enum glacier.widget.textbox.signals
local signals = {
    ---Emitted when the TextBox's content changes.
    CONTENT_CHANGED = "glacier::widget::textbox::content_changed",
}

---@class glacier.widget.textbox.Event
---@field set? string
---@field empty? {}

---@class glacier.widget.textbox.Message
---@field id integer
---@field event glacier.widget.textbox.Event

---Style to apply when rendering the `TextBox`.
---
---@class glacier.widget.textbox.Style
---@field fg_color? snowcap.widget.Color Foreground color. Used to display text.
---@field bg_color? snowcap.widget.Color Background color.
---@field border? snowcap.widget.Border Border option for the container around the text.
---@field pixels? number Size of the text, in pixel.
---@field font? snowcap.widget.Font Text font.
---@field padding? snowcap.widget.Padding Container Padding.
local Style = {}

---Collection of styles.
---
---@class glacier.widget.textbox.Styles: glacier.widget.textbox.Style
---@field styles? table<string, glacier.widget.textbox.Style> Per content override.

---TextBox configuration options
---
---@class (exact) glacier.widget.textbox.Config
---@field content? string Initial text content
---@field style? glacier.widget.textbox.Styles|glacier.widget.textbox.StyleFn
---@field view_callback? glacier.widget.textbox.ViewFn

---Simple widget to display text.
---
---@class glacier.widget.TextBox: snowcap.widget.Program
---@field private content string TextBox content
---Function called with the `TextBox` content to get a `Style`.
---@field private style_fn glacier.widget.textbox.StyleFn
---@field private view_callback? glacier.widget.textbox.ViewFn Rendering function
local TextBox = setmetatable({}, { __index = require("snowcap.widget.base").Base })

----------------------
-- Module functions --
----------------------

---Default view_fn for [`TextBox`].
---
---@param content string The text to render
---@param style glacier.widget.textbox.Style Style to apply.
---@return snowcap.widget.WidgetDef
function textbox.default_view(content, style)
    local widget = Widget.container({
        height = Widget.length.Fill,
        width = Widget.length.Shrink,
        valign = Widget.alignment.CENTER,
        padding = style.padding,
        style = style:to_container(),
        child = Widget.text({
            text = content,
            height = Widget.length.Fill,
            valign = Widget.alignment.CENTER,
            style = style:to_text(),
        }),
    })

    return widget
end

---Default style for [`TextBox`]
---@return glacier.widget.textbox.Styles
function textbox.default_style()
    return {}
end

---@package
---Wrap a `Styles` in a `StyleFn`
---
---@param style glacier.widget.textbox.Styles
---@return glacier.widget.textbox.StyleFn
local function _style_lookup(style)
    return function(content)
        local deep_copy = require("snowcap.util").deep_copy

        ---@type glacier.widget.textbox.Style
        local ret = {}

        for k, v in pairs(style) do
            if k ~= "styles" then
                ret[k] = deep_copy(v)
            end
        end

        if style.styles and style.styles[content] then
            ret = require("glacier.utils").merge_table(ret, style.styles[content])
        end

        return ret
    end
end

--------------------------
-- Style public methods --
--------------------------

---Convert a style to a `snowcap.widget.container.Style`
---
---@return snowcap.widget.container.Style
function Style:to_container()
    ---@type snowcap.widget.container.Style
    return {
        text_color = self.fg_color,
        background = self.bg_color and Widget.background.Color(self.bg_color),
        border = self.border,
    }
end

---Convert a style to a `snowcap.widget.text.Style`.
---
---@return snowcap.widget.text.Style
function Style:to_text()
    ---@type snowcap.widget.text.Style
    return {
        color = self.fg_color,
        pixels = self.pixels,
        font = self.font,
    }
end

--------------------
-- Style lifetime --
--------------------

---@package
---Create a new Style.
---
---@param style glacier.widget.textbox.Style
---@return glacier.widget.textbox.Style
function Style:new(style)
    style = style or {}

    setmetatable(style, { __index = Style })

    return style
end

----------------------------
-- TextBox public methods --
----------------------------

---Set the TextBox content.
---
---@param content string
function TextBox:set_content(content)
    ---@type glacier.widget.textbox.Message
    local msg = {
        id = self:id(),
        event = {
            set = content,
        },
    }

    self:emit(StdSig.send_message, msg)
end

---Connect the TextBox to other widget or signalers
---
---The `TextBox` will connect to is standard messages. For arbitrary signal support,
---use `connect_with` instead.
---@param widget snowcap.widget.base.Base|snowcap.signal.Signaler
---@return snowcap.signal.SignalHandle
function TextBox:connect_to(widget)
    local weak = require("glacier.utils").weak(self)

    return widget:connect(signals.CONTENT_CHANGED, function(content)
        local tb = weak:get()

        if tb == nil then
            return Signal.HandlerPolicy.Discard
        end

        tb:set_content(content)
        return Signal.HandlerPolicy.Keep
    end)
end

---Connect the TextBox to arbitrary signals.
---
---@param signaler snowcap.widget.base.Base|snowcap.signal.Signaler
---@param processor fun(textbox: glacier.widget.TextBox, ...): snowcap.signal.HandlerPolicy?
---@return snowcap.signal.SignalHandle
function TextBox:connect_with(signaler, name, processor)
    local weak = require("glacier.utils").weak(self)

    return signaler:connect(name, function(...)
        local tb = weak:get()

        if tb == nil then
            return Signal.HandlerPolicy.Discard
        end

        return processor(tb, ...)
    end)
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
function TextBox:view()
    local style = self.style_fn(self.content) or {}

    local view_callback = self.view_callback or textbox.default_view

    return view_callback(self.content, Style:new(style))
end

---Updates this widget program with the received message.
---@param msg any
function TextBox:update(msg)
    if msg and msg.id == self:id() and msg.event ~= nil then
        local content = self.content

        ---@cast msg glacier.widget.textbox.Message
        if msg.event.set ~= nil then
            self.content = msg.event.set
        elseif msg.event.empty ~= nil then
            self.content = ""
        end

        if content ~= self.content then
            self:emit(signals.CONTENT_CHANGED, self.content)
        end
    end
end

---Called when a surface has been created with this program.
---
---A surface handle is provided to allow the program to manupulate
---the surface. This handle should be passed to any child programs
---to allow them to use it as well.
---
---@param _ snowcap.widget.SurfaceEvent
function TextBox:event(_) end

-----------
-- Other --
-----------

---Create a new [`TextBox`].
---@param config glacier.widget.textbox.Config
---@return glacier.widget.TextBox
function TextBox:new(config)
    config = config or {}
    config.content = config.content or ""

    ---@type glacier.widget.textbox.StyleFn
    local style_fn
    if config.style == nil then
        style_fn = _style_lookup(textbox.default_style())
    elseif type(config.style) == "function" then
        style_fn = config.style --[[@as glacier.widget.textbox.StyleFn]]
    elseif type(config.style) == "table" then
        style_fn = _style_lookup(config.style --[[@as glacier.widget.textbox.Styles]])
    else
        Log.error("Unexpected type for Config::style. Got " .. type(config.style))
        style_fn = _style_lookup(textbox.default_style())
    end

    local base = require("snowcap.widget.base").Base.new()
    local ret = setmetatable(base, { __index = TextBox }) --[[@as glacier.widget.TextBox]]

    ret.content = config.content
    ret.style_fn = style_fn
    ret.view_callback = config.view_callback

    return ret
end

---Create a new [`TextBox`].
---@param ... glacier.widget.textbox.Config
---@return glacier.widget.TextBox
function textbox.mt:__call(...)
    return TextBox:new(...)
end

textbox.signals = signals
textbox.TextBox = TextBox

---@diagnostic disable-next-line:param-type-mismatch
return setmetatable(textbox, textbox.mt) --[[@as glacier.widget.textbox]]
