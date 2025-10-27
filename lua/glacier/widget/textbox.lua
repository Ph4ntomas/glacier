local Log = require("snowcap.log")
local Widget = require("snowcap.widget")

local Base = require("glacier.widget.base")

---Function to call to render the text widget
---@alias glacier.widget.textbox.ViewFn fun(text: string, style: glacier.widget.textbox.Style): snowcap.widget.WidgetDef

---Function to retrieve a style based on the TextBox content
---
---@alias glacier.widget.textbox.StyleFn fun(text: string): glacier.widget.textbox.Style?

---glacier.widget.textbox module.
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

---Collection of styles.
---
---@class glacier.widget.textbox.Styles: glacier.widget.textbox.Style
---@field styles? table<string, glacier.widget.textbox.Style> Per content styling.

---@package
---Wrap a `glacier.widget.textbox.Styles` in a `glacier.widget.textbox.StyleFn`
---
---@param style glacier.widget.textbox.Styles
---@return glacier.widget.textbox.StyleFn
local function _style_lookup(style)
    return function(content)
        if style.styles and style.styles[content] then
            return style[content]
        else
            return style
        end
    end
end

---Utility functions for `glacier.widget.textbox.Style`.
---
---@class glacier.widget.textbox.style
local _style = {}

---Convert a `glacier.widget.textbox.Style` to a `snowcap.widget.container.Style`.
---
---@param style? glacier.widget.textbox.Style
---@return snowcap.widget.container.Style?
function _style.to_container(style)
    if not style then
        return nil
    end

    return {
        text_color = style.fg_color,
        background_color = style.bg_color,
        border = style.border,
    }
end

---Convert a `glacier.widget.textbox.Style` to a `snowcap.widget.text.Style`.
---
---@param style? glacier.widget.textbox.Style
---@return snowcap.widget.text.Style?
function _style.to_text(style)
    if not style then
        return nil
    end

    return {
        color = style.fg_color,
        pixels = style.pixels,
        font = style.font,
    }
end

textbox.style = _style

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
---@param style? glacier.widget.textbox.Style
---@return snowcap.widget.WidgetDef
function textbox.default_view(content, style)
    local widget = Widget.container({
        height = Widget.length.Fill,
        width = Widget.length.Shrink,
        valign = Widget.alignment.CENTER,
        style = textbox.style.to_container(style),
        child = Widget.text({
            text = content,
            style = textbox.style.to_text(style),
        }),
    })

    return widget
end

---Create the view for this textbox.
---
---@return snowcap.widget.WidgetDef
function TextBox:view()
    return self.view_fn(self.content, self.style_fn(self.content))
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
            return nil
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
        return nil
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
