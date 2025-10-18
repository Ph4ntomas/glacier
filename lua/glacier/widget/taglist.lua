local Log = require("pinnacle.log") ---@diagnostic disable-line:unused-local
local Tag = require("pinnacle.tag")
local Output = require("pinnacle.output")
local Widget = require("snowcap.widget")
local Posix = require("posix")

local Base = require("glacier.widget.base")
local widget_signal = require("glacier.widget.signal")

---Internal taglist module
---@package
local _taglist = {}

---glacier.widget.taglist module.
---
---@class glacier.widget.taglist
---@field mt metatable This module metatable
---@overload fun(...:glacier.widget.taglist.Config):glacier.widget.TagList
local taglist = { mt = {} }

---`TagList` configuration object.
---
---@class glacier.widget.taglist.Config
---@field output pinnacle.output.OutputHandle
---@field style? glacier.widget.taglist.Style
---@field throttle_scroll? number

---Style to apply when building the tags widgets.
---
---@class glacier.widget.taglist.TagStyle
---@field text? snowcap.widget.Color
---@field font? snowcap.widget.Font
---@field pixels? number
---@field border? snowcap.widget.Border,
---@field background? snowcap.widget.Color,
local TagStyle = {}

---Create a new `TagStyle`.
---
---@param s glacier.widget.taglist.TagStyle
function TagStyle:new(s)
    ---@type glacier.widget.taglist.TagStyle
    ---@diagnostic disable-next-line:redefined-local
    local s = s or {}

    setmetatable(s, self)
    self.__index = self

    return s
end

---Create a text `Style` from this `TagStyle`.
---
---@return snowcap.widget.text.Style
function TagStyle:text_style()
    return {
        font = self.font,
        pixels = self.pixels,
    }
end

---Create a button `Style` from this `TagStyle`.
---
---@return snowcap.widget.button.Style
function TagStyle:button_style()
    return {
        text_color = self.text,
        background_color = self.background,
        border = self.border,
    }
end

---Create a callback that will brighten the background of a `TagStyle` by a specified amount.
---
---@param amount number
---@return fun(style: glacier.widget.taglist.TagStyle): glacier.widget.taglist.TagStyle
function TagStyle.brighten(amount)
    ---@param self glacier.widget.taglist.TagStyle
    local function transform(self)
        local color = self.background
        if color then
            color.red = color.red + amount
            color.green = color.green + amount
            color.blue = color.blue + amount
        end

        return self
    end

    return transform
end

---Style to apply to every Tag widget in a `TagList`.
---
---@class glacier.widget.taglist.Style
---@field active? glacier.widget.taglist.TagStyle
---@field inactive? glacier.widget.taglist.TagStyle
---@field padding? snowcap.widget.Padding,
---@field hover_transform? fun(glacier.widget.taglist.TagStyle): glacier.widget.taglist.TagStyle
local Style = {}

---Create a new `Style`.
---
---@return glacier.widget.taglist.Style
function Style:new(style)
    ---@diagnostic disable-next-line:redefined-local
    local style = style or {}

    local s = {
        active = TagStyle:new(style.active or {}),
        inactive = TagStyle:new(style.inactive or {}),
        padding = style.padding or {},
        hover_transform = style.hover_transform or TagStyle.brighten(0.05),
    }

    setmetatable(s, self)
    self.__index = self

    return s
end

---Apply this Style hover_transform to a `TagStyle`.
---
---@param tag_style glacier.widget.taglist.TagStyle
function Style:to_hover(tag_style)
    local deep_copy = require("pinnacle.util").deep_copy(tag_style)

    if self.hover_transform then
        return self.hover_transform(deep_copy)
    else
        return deep_copy
    end
end

---Action to execute upon an update.
---
---@class glacier.widget.taglist.MessageAction
---@field action glacier.widget.taglist.Action
---@field tag? pinnacle.tag.TagHandle

---Type of to execute on an update. These are meant to be used in the TagList:view() function.
---@enum glacier.widget.taglist.Action
_taglist.Action = {
    TOGGLE = "taglist::toggle_tag",
    SWITCH = "taglist::switch_tag",
    NEXT_TAG = "taglist::next_tag",
    PREV_TAG = "taglist::previous_tag",
    SMALL_SCROLL = "taglist::small_scroll",
    ---@type fun(handle: pinnacle.tag.TagHandle): glacier.widget.taglist.MessageAction
    Toggle = function(handle)
        return { action = _taglist.Action.TOGGLE, tag = handle }
    end,
    ---@type fun(handle: pinnacle.tag.TagHandle): glacier.widget.taglist.MessageAction
    Switch = function(handle)
        return { action = _taglist.Action.SWITCH, tag = handle }
    end,
    ---@type fun(): glacier.widget.taglist.MessageAction
    NextTag = function()
        return { action = _taglist.Action.NEXT_TAG }
    end,
    ---@type fun(): glacier.widget.taglist.MessageAction
    PrevTag = function()
        return { action = _taglist.Action.PREV_TAG }
    end,
    ---@type fun(): glacier.widget.taglist.MessageAction
    SmallScroll = function()
        return { action = _taglist.Action.SMALL_SCROLL }
    end,
}

---Internal representation of a Tag.
---
---@class glacier.widget.taglist.Tag
---@field handle pinnacle.tag.TagHandle
---@field name string
---@field active boolean
_taglist.Tag = {}

---Convert a `taglist.Tag` to a string.
---
---@return string
function _taglist.Tag:__tostring()
    return ("<tag#%d#%s active=%q>"):format(self.handle.id, self.name, self.active)
end

---Create new `taglist.Tag`.
---
---@param tag glacier.widget.taglist.Tag
---@return glacier.widget.taglist.Tag
function _taglist.Tag:new(tag)
    setmetatable(tag, self)
    self.__index = self

    return tag
end

---Widget that display a list of Tags for a given output.
---
---@class glacier.widget.TagList: glacier.widget.Base
---@field output pinnacle.output.OutputHandle Handle to this list `Output`.
---@field style? glacier.widget.taglist.Style Style to apply when building the `TagList`.
---@field throttle_scroll number Throttle scroll event.
---@field private tags glacier.widget.taglist.Tag[] List of `Tag`s in this list.
---@field private prev_scroll number Last time a scroll event happened.
local TagList = Base:new_class({ type = "TagList" })

---Generate a `WidgetDef` per tags in this `TagList`.
---
---@return snowcap.widget.WidgetDef[]
function TagList:view_tags()
    local list = {}

    for _, v in pairs(self.tags) do
        local style = v.active and self.style.active or self.style.inactive --[[@as glacier.widget.taglist.TagStyle]]
        local hovered_style = self.style:to_hover(style)

        local view = Widget.mouse_area({
            callbacks = {
                on_right_release = {
                    widget_id = self:id(),
                    action = _taglist.Action.Toggle(v.handle),
                },
            },
            child = Widget.button({
                on_press = { widget_id = self:id(), action = _taglist.Action.Switch(v.handle) },
                style = {
                    active = style:button_style(),
                    pressed = style:button_style(),
                    hovered = hovered_style:button_style(),
                    disabled = style:button_style(),
                },
                height = Widget.length.Fill,
                valign = Widget.alignment.CENTER,
                padding = self.style.padding,
                child = Widget.text({
                    text = v.name,
                    height = Widget.length.Fill,
                    valign = Widget.alignment.CENTER,
                    style = style:text_style(),
                }),
            }),
        })

        table.insert(list, view)
    end

    return list
end

---Generate a `WidgetDef` for this `TagList`.
---
---If the `TagList` is empty, nil is returned.
---@return snowcap.widget.WidgetDef|nil
function TagList:view()
    local children = self:view_tags()
    if #children == 0 then
        return
    end

    local list = Widget.mouse_area({
        callbacks = {
            on_scroll = function(delta)
                local value = 0
                if delta.pixels then
                    local dx = delta.pixels.x or 0.0
                    local dy = delta.pixels.y or 0.0
                    local delta = dy ---@diagnostic disable-line:redefined-local

                    if math.abs(dx) > math.abs(dy) then
                        delta = dx
                    end

                    if math.abs(delta) < 0.5 then
                        value = 0
                    else
                        value = delta > 0 and 1 or -1
                    end
                elseif delta.lines then
                    local dx = delta.lines.x or 0.0
                    local dy = delta.lines.y or 0.0
                    local delta = dy ---@diagnostic disable-line:redefined-local

                    if math.abs(dx) > math.abs(dy) then
                        delta = dx
                    end

                    value = delta > 0 and 1 or -1
                end

                local action = _taglist.Action.SmallScroll

                if value > 0 then
                    action = _taglist.Action.NextTag
                elseif value < 0 then
                    action = _taglist.Action.PrevTag
                end

                return { widget_id = self:id(), action = action() }
            end,
        },
        child = Widget.row({
            height = Widget.length.Fill,
            item_alignment = Widget.alignment.CENTER,
            children = children,
        }),
    })

    return list
end

---Find the first active tag & return its index.
---
---If there are no focused tag, 0 is returned instead.
---@private
---@return integer
function TagList:find_active_idx()
    local idx = 0

    for k, tag in pairs(self.tags) do
        if tag.active then
            idx = k
            break
        end
    end

    return idx
end

---Focus the next tag in the list.
---
---If no tag is focused, or if the last tag is, this function will focus the
---first tag of the list.
---@private
function TagList:focus_next_tag()
    local idx = self:find_active_idx()
    idx = idx + 1

    if idx > #self.tags then
        idx = 1
    end

    local tag = self.tags[idx]
    if tag then
        tag.handle:switch_to()
    end
end

---Focus previous tag in the list.
---
---If no tag is focused, or if the first tag is, this function will focus the
---last tag of this list.
---@private
function TagList:focus_prev_tag()
    local idx = self:find_active_idx()
    idx = idx - 1

    if idx <= 0 then
        idx = #self.tags or 1
    end

    local tag = self.tags[idx]
    if tag then
        tag.handle:switch_to()
    end
end

---Update the TagList internal state and react to messages.
---
---@param msg any The message to react to.
function TagList:update(msg)
    if not msg then
        return
    end

    if msg.widget_id == self:id() then
        ---@diagnostic disable-next-line:redefined-local
        local msg = msg.action --[[@as glacier.widget.taglist.MessageAction]]

        if msg.action == _taglist.Action.SWITCH then
            msg.tag:switch_to()
        elseif msg.action == _taglist.Action.TOGGLE then
            msg.tag:toggle_active()
        else
            local sec, nsec = Posix.clock_gettime(0)
            local now = sec + nsec / 10 ^ 9
            local diff = now - self.prev_scroll

            if self.throttle_scroll < diff then
                self.prev_scroll = now
                if msg.action == _taglist.Action.PREV_TAG then
                    self:focus_prev_tag()
                elseif msg.action == _taglist.Action.NEXT_TAG then
                    self:focus_next_tag()
                end
            end
        end
    end
end

---Convert a set of `TagHandle` to `Tag`.
---
---@private
---@param handles pinnacle.tag.TagHandle[]
---@return glacier.widget.taglist.Tag[]
function TagList:to_tags(handles)
    local list = {}

    local requests = {}

    for i, handle in pairs(handles) do
        requests[i] = function()
            return {
                output = handle:output(),
                name = handle:name(),
                active = handle:active(),
            }
        end
    end

    local props = require("pinnacle.util").batch(requests)

    for i, prop in pairs(props) do
        if prop.output.name == self.output.name then
            table.insert(
                list,
                _taglist.Tag:new({
                    handle = handles[i],
                    name = prop.name,
                    active = prop.active,
                })
            )
        end
    end

    return list
end

---Get all tags for the output managed by this `TagList`.
---
---@private
---@return glacier.widget.taglist.Tag[]
function TagList:get_all_tags()
    local handles = Tag.get_all()

    return self:to_tags(handles)
end

---Convert a single TagHandle to a `Tag`.
---
---@private
---@return glacier.widget.taglist.Tag?
function TagList:get_tag(handle)
    local list = self:to_tags({ handle })

    return list[1]
end

---Refresh the `TagList`.
---
---This function will emit `"widget::redraw_needed"`.
function TagList:refresh()
    self:emit(widget_signal.redraw_needed)
end

---Setup the `TagList` signals.
---
---@private
function TagList:setup_signals()
    Tag.connect_signal({
        active = function(handle, active)
            for _, tag in pairs(self.tags) do
                if tag.handle.id == handle.id then
                    tag.active = active
                    self:refresh()
                    return
                end
            end
        end,
    })
end

---Convert the `TagList` to a string.
---
---@return string
function TagList:__tostring()
    return ("<%s#%q#%s>"):format(self.type, self:id(), self.output.name)
end

---Create a new `TagList`.
---
---@param config glacier.widget.taglist.Config
---@return glacier.widget.TagList
function TagList:new(config)
    ---@diagnostic disable-next-line: redefined-local
    local config = config or {}
    config.output = config.output or Output.get_focused()

    ---@type glacier.widget.TagList
    ---@diagnostic disable-next-line
    local taglist = TagList:super({
        output = config.output,
        tags = {},
        style = Style:new(config.style),
        throttle_scroll = config.throttle_scroll or 0.05,
        prev_scroll = 0.0,
    })

    taglist.tags = taglist:get_all_tags()

    taglist:setup_signals()

    return taglist
end

---Build a new `TagList` widget.
---
---@param config glacier.widget.taglist.Config
---@return glacier.widget.TagList
function taglist.mt:__call(config)
    config = config or {}

    local default_config = {
        output = config.output or Output.get_focused(),
        style = {
            ---@type glacier.widget.taglist.TagStyle
            active = {
                text = Widget.color.from_rgba(0.8, 0.8, 0.8),
                font = {
                    family = Widget.font.family.Monospace,
                    weight = Widget.font.weight.BOLD,
                },
                border = { width = 0 },
                background = Widget.color.from_rgba(0.2, 0.6, 0.1),
            },
            inactive = {
                text = Widget.color.from_rgba(0.7, 0.7, 0.7),
                font = {
                    family = Widget.font.family.Monospace,
                    weight = Widget.font.weight.BOLD,
                },
                border = { width = 0 },
                background = Widget.color.from_rgba(0.4, 0.4, 0.4),
            },
            padding = {
                top = 2,
                bottom = 2,
                left = 8,
                right = 8,
            },
            hover_transform = TagStyle.brighten(0.05),
        },
        throttle_scroll = config.throttle_scroll or 0.05,
    }

    ---@diagnostic disable-next-line:redefined-local
    local config = require("glacier.utils").merge_table(default_config, config)

    return TagList:new(config)
end

---@diagnostic disable-next-line: param-type-mismatch
return setmetatable(taglist, taglist.mt) --[[@as glacier.widget.taglist]]
