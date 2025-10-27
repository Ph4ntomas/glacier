local Log = require("snowcap.log")
local Widget = require("snowcap.widget")

local Base = require("glacier.widget.base")

---Function to call to render the text widget
---@alias glacier.widget.textbox.ViewFn fun(text: string, style: glacier.widget.textbox.Style?): snowcap.widget.WidgetDef

---Function to retrieve a style based on the TextBox content
---@alias glacier.widget.textbox.StyleFn fun(text: string): glacier.widget.textbox.Style

---glacier.widget.textbox module.
---
---This module introduces a simple widget to display text. The TextBox object can be used in other
---Glacier layers (e.g. the bar), and will properly notify the underlying layer when its content
---is updated.
---
---## Styling
---### Basic style
---Styling can be applied globally, by passing a `glacier.widget.textbox.Style` object on creation,
---or by calling the `TextBox.set_style` function.
---
---The style is then passed to the view function when it need to be rendered.
---
---### Per content Styling
---It's possible to set style override based on the content of the textbox. This is useful if the
---textbox is expected to only hold simple string known ahead of time. To set per-content styling,
---simply add a `styles` table the object passed on initialization or the `set_style` function.  
---At render time, the TextBox will lookup its content in the table, and merge the object with the
---default one.
---
---```lua
---glacier.widget.textbox({
---    ...
---    style = {
---        [...] -- default option
---        bg_color = Widget.color.from_rgba(0, 1.0, 0) -- By default, the background is green.
---        styles = {
---            foo = {
---                 bg_color = Widget.color.from_rgba(1.0, 0, 0) -- when the text is exactly 'foo', this color will be used instead.
---            }
---        }
---    }
---})
---```
---
---### Advanced styling
---Instead of a static style, or per-content styling, it's also possible to pass a 
---`glacier.widget.textbox.StyleFn`. This function will be called with the content of the textbox,
---whenever a view need to be generated. This can be used if you need to match part of the string
---to apply a specific style.
---
---## Changing the view
---As with most widgets, it's possible to override the way the view is rendered.
---
---### Global override
---Upon creation, TextBox will loopup the `glacier.widget.textbox.view_fn` field. If set, it will
---be used instead of `glacier.widget.textbox.default_view.
---
---### Per widget override
---It's also possible to set the view_fn of a single widget, either at creation time, or by calling
---`TextBox:set_view_fn`.
---
---@class glacier.widget.textbox
---@field mt metatable This module metatable.
---@field view_fn glacier.widget.clock.ViewFn Global view function.
---
---@overload fun(...: glacier.widget.textbox.Config): glacier.widget.textbox.TextBox
local textbox = { mt = {} }

---Style to apply when rendering the `glacier.widget.textbox.TextBox`.
---
---@class glacier.widget.textbox.Style
---@field fg_color? snowcap.widget.Color Foreground color. Used to display text.
---@field bg_color? snowcap.widget.Color Background color.
---@field border? snowcap.widget.Border Border option for the container around the text.
---@field pixels? number Size of the text, in pixel.
---@field font? snowcap.widget.Font Text font.
---@field padding? snowcap.widget.Padding Container Padding.
local Style = {}

---Create a new instance of `glacier.widget.textbox.Style`
---
---@param style glacier.widget.textbox.Style
---@return glacier.widget.textbox.Style
function Style:new(style)
    style = style or {}

    setmetatable(style, self)
    self.__index = self
    self.__tostring = self.__tostring

    return style
end

---Convert this Style object into a string.
---@return string
function Style:__tostring()
    return "<textbox.Style>"
end

---Convert the style object into a `snowcap.widget.text.Style`
---@return snowcap.widget.text.Style
function Style:to_text()
    ---@type snowcap.widget.text.Style
    return {
        color = self.fg_color,
        pixels = self.pixels,
        font = self.font,
    }
end

---Convert the style object into a `snowcap.widget.container.Style`
---@return snowcap.widget.container.Style
function Style:to_container()
    ---@type snowcap.widget.container.Style
    return {
        text_color = self.fg_color,
        background_color = self.bg_color,
        border = self.border,
    }
end

---Collection of styles.
---
---@class glacier.widget.textbox.Styles: glacier.widget.textbox.Style
---@field styles? table<string, glacier.widget.textbox.Style> Per content override.

---@package
---Wrap a `glacier.widget.textbox.Styles` in a `glacier.widget.textbox.StyleFn`
---
---@param style glacier.widget.textbox.Styles
---@return glacier.widget.textbox.StyleFn
local function _style_lookup(style)
    return function(content)
        local deep_copy = require("snowcap.util").deep_copy
        ---@type glacier.widget.textbox.Style
        local ret = {
            fg_color = deep_copy(style.fg_color),
            bg_color = deep_copy(style.bg_color),
            border = deep_copy(style.border),
            pixels = deep_copy(style.pixels),
            font = deep_copy(style.font),
            padding = deep_copy(style.padding),
        }

        if style.styles and style.styles[content] then
            ret = require("glacier.utils").merge_table(ret, style.styles[content])
        end

        return ret
    end
end

---Simple widget to display text.
---
---@class glacier.widget.textbox.TextBox : glacier.widget.Base
---@field private content string TextBox content
---Function called with the `TextBox` content to get a `Style`
---@field private style_fn glacier.widget.textbox.StyleFn
---@field private view_fn glacier.widget.textbox.ViewFn Rendering function.
local TextBox = Base:new_class({ type = "TextBox" })

---Default view_fn for textbox
---
---@param content string
---@param style glacier.widget.textbox.Style
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

---Create the view for this textbox.
---
---@return snowcap.widget.WidgetDef
function TextBox:view()
    local style = self.style_fn(self.content) or {}

    return self.view_fn(self.content, Style:new(style))
end

---Override the view function used to render this TextBox.
---
---@param view_fn glacier.widget.textbox.ViewFn
function TextBox:set_view_fn(view_fn)
    self.view_fn = view_fn or textbox.view_fn or textbox.default_view

    self:refresh()
end

---Access this TextBox content.
---
---@return string
function TextBox:get()
    return self.content
end

---Modify this TextBox content.
---
---After setting the new content, the TextBox will emit a signal to notify the underlying layer of
---the change.
---
---@param content string
function TextBox:set(content)
    self.content = content or ""

    self:refresh()
end

---Change this TextBox style.
---
---@param style glacier.widget.textbox.Styles|glacier.widget.textbox.StyleFn
function TextBox:set_style(style)
    if type(style) == "function" then
        self.style_fn = style
    elseif type(style) == "table" then
        self.style_fn = _style_lookup(style)
    elseif not style then
        self.style_fn = function(_)
            return {}
        end
    else
        Log.error("Unexpected Style type. Got " .. type(style))
    end

    self:refresh()
end

---@class glacier.widget.textbox.Config
---@field content? string Initial text content
---Style to be applied, or a function which return a style based on the textbox content.
---@field style? glacier.widget.textbox.Styles|glacier.widget.textbox.StyleFn
---@field view_fn? glacier.widget.textbox.ViewFn Rendering function.

---Create a new TextBox
---@param config glacier.widget.textbox.Config
---@return glacier.widget.textbox.TextBox
function TextBox:new(config)
    config = config or {}

    ---@type glacier.widget.textbox.Config
    local default_config = {
        content = "",
        view_fn = textbox.view_fn or textbox.default_view,
    }

    config = require("glacier.utils").merge_table(default_config, config)

    ---@type glacier.widget.textbox.StyleFn
    local style_fn = nil

    if config.style then
        if type(config.style) == "function" then
            style_fn = config.style
        elseif type(config.style) == table then
            style_fn = _style_lookup(config.style)
        else
            Log.error("Unexpected type for Config::style. Got " .. type(config.style))
        end
    end

    style_fn = style_fn or function(_)
        return {}
    end

    local ret = TextBox:super({
        content = config.content,
        style_fn = style_fn,
        view_fn = config.view_fn,
    })

    return ret
end

function textbox.mt:__call(...)
    return TextBox:new(...)
end

textbox.TextBox = TextBox

---@diagnostic disable-next-line:param-type-mismatch
return setmetatable(textbox, textbox.mt) --[[ @as glacier.widget.textbox ]]
