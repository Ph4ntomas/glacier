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

---Function to call when rendering a single tag.
---@alias glacier.widget.taglist.InnerViewFn fun(tag_name: string, tag: glacier.widget.taglist.TagStyle):snowcap.widget.WidgetDef

---Function to call when rendering the list itself.
---
---@alias glacier.widget.taglist.OuterViewFn fun(children: snowcap.widget.WidgetDef[], tag: glacier.widget.taglist.Style):snowcap.widget.WidgetDef

---glacier.widget.taglist module.
---
---@class glacier.widget.taglist
---@field mt metatable This module metatable
---@field inner_view glacier.widget.taglist.InnerViewFn Function to override the default rendering of each tags button.
---@field outer_view glacier.widget.taglist.OuterViewFn Function to override the default rendering of the list of tags.
---@field TagList glacier.widget.taglist.TagList Widget class.
---
---@overload fun(...:glacier.widget.taglist.Config):glacier.widget.taglist.TagList
local taglist = { mt = {} }

---Style to apply when building the tags widgets.
---
---@class glacier.widget.taglist.TagStyle
---@field text? snowcap.widget.Color
---@field font? snowcap.widget.Font
---@field pixels? number
---@field border? snowcap.widget.Border
---@field background? snowcap.widget.Color
---@field padding? snowcap.widget.Padding
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

---Create a callback that will brighten the background of a `TagStyle` by a specified amount.
---
---@param amount number
---@return fun(style: glacier.widget.taglist.TagStyle): glacier.widget.taglist.TagStyle
function taglist.brighten(amount)
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
---@field spacing? number
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
        spacing = style.spacing or 0,
        hover_transform = style.hover_transform,
    }

    s.active.padding = s.active.padding or s.padding
    s.inactive.padding = s.inactive.padding or s.padding

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
    ENTER_TAG = "taglist::enter_tag",
    EXIT_TAG = "taglist::exit_tag",
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
    EnterTag = function(handle)
        return { action = _taglist.Action.ENTER_TAG, tag = handle }
    end,
    ExitTag = function(handle)
        return { action = _taglist.Action.EXIT_TAG, tag = handle }
    end,
}

---Internal representation of a Tag.
---
---@class glacier.widget.taglist.Tag
---@field handle pinnacle.tag.TagHandle
---@field name string
---@field active boolean
---@field hovered boolean
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

---Render the content of the tag button.
---
---@param tag_name string Name of the tag to display
---@param style glacier.widget.taglist.TagStyle Styling option for the tag.
---@return snowcap.widget.WidgetDef
---@diagnostic disable-next-line: unused-local
function taglist.default_inner_view(tag_name, style)
    return Widget.container({
        style = {
            background_color = style.background,
        },
        padding = style.padding,
        child = Widget.text({
            text = tag_name,
            height = Widget.length.Fill,
            valign = Widget.alignment.CENTER,
            style = style:text_style(),
        }),
    })
end

---Render the tag list.
---
---@param children snowcap.widget.WidgetDef[]
---@param style glacier.widget.taglist.Style
---@return snowcap.widget.WidgetDef
function taglist.default_outer_view(children, style)
    return Widget.row({
        height = Widget.length.Fill,
        item_alignment = Widget.alignment.CENTER,
        spacing = style.spacing,
        children = children,
    })
end

---Widget that display a list of Tags for a given output.
---
---@class glacier.widget.taglist.TagList: glacier.widget.Base
---@field output pinnacle.output.OutputHandle Handle to this list `Output`.
---@field style? glacier.widget.taglist.Style Style to apply when building the `TagList`.
---@field throttle_scroll number Throttle scroll event.
---@field inner_view glacier.widget.taglist.InnerViewFn Function to override the rendering of the tag button child.
---@field outer_view glacier.widget.taglist.OuterViewFn Function to override the rendering of the list of tags.
---@field private tags glacier.widget.taglist.Tag[] List of `Tag`s in this list.
---@field private prev_scroll number Last time a scroll event happened.
local TagList = Base:new_class({ type = "TagList" })

---Transform a scroll event to a message.
---
---@param delta snowcap.widget.mouse_area.ScrollEvent
---@return any
function TagList:on_scroll(delta)
    local value = 0
    if delta.pixels then
        local dx = delta.pixels.x or 0.0
        local dy = delta.pixels.y or 0.0
        local delta = dy ---@diagnostic disable-line:redefined-local

        if math.abs(dx) > math.abs(dy) then
            delta = dx
        end

        if math.abs(delta) < 0.50 then
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
end

---Generate a `WidgetDef` per tags in this `TagList`.
---
---@return snowcap.widget.WidgetDef[]
function TagList:view_tags()
    local list = {}

    for _, v in pairs(self.tags) do
        local style = v.active and self.style.active or self.style.inactive --[[@as glacier.widget.taglist.TagStyle]]
        if v.hovered then
            style = self.style:to_hover(style)
        end

        local view = Widget.mouse_area({
            on_right_release = {
                widget_id = self:id(),
                action = _taglist.Action.Toggle(v.handle),
            },
            on_release = {
                widget_id = self:id(),
                action = _taglist.Action.Switch(v.handle),
            },
            on_enter = {
                widget_id = self:id(),
                action = _taglist.Action.EnterTag(v.handle),
            },
            on_exit = {
                widget_id = self:id(),
                action = _taglist.Action.ExitTag(v.handle),
            },
            child = self.inner_view(v.name, style),
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
        on_scroll = function(delta)
            return self:on_scroll(delta)
        end,
        child = self.outer_view(children, self.style),
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

---Find a tag, given its handle.
---
---@param handle pinnacle.tag.TagHandle
---@return glacier.widget.taglist.Tag?
function TagList:find_by_handle(handle)
    for _, tag in pairs(self.tags) do
        if tag.handle.id == handle.id then
            return tag
        end
    end

    return nil
end

---Set the hover flag of a tag
---
---@param handle pinnacle.tag.TagHandle
---@param hover boolean
function TagList:set_hover_for(handle, hover)
    local tag = self:find_by_handle(handle)

    if tag then
        tag.hovered = hover
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
        elseif msg.action == _taglist.Action.ENTER_TAG then
            self:set_hover_for(msg.tag, true)
        elseif msg.action == _taglist.Action.EXIT_TAG then
            self:set_hover_for(msg.tag, false)
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
                    hovered = false,
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

---`TagList` configuration object.
---
---@class glacier.widget.taglist.Config
---@field output pinnacle.output.OutputHandle
---@field style? glacier.widget.taglist.Style
---@field throttle_scroll? number
---@field inner_view? glacier.widget.taglist.InnerViewFn Function to override the default rendering of each tags.
---@field outer_view? glacier.widget.taglist.OuterViewFn Function to override the default rendering of the list of tags.

---Create a new `TagList`.
---
---@param config glacier.widget.taglist.Config
---@return glacier.widget.taglist.TagList
function TagList:new(config)
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
            spacing = 0,
            hover_transform = nil,
        },
        throttle_scroll = config.throttle_scroll or 0.05,
        inner_view = taglist.inner_view or taglist.default_inner_view,
        outer_view = taglist.outer_view or taglist.default_outer_view,
    }

    ---@diagnostic disable-next-line:redefined-local
    local config = require("glacier.utils").merge_table(default_config, config)

    ---@type glacier.widget.taglist.TagList
    ---@diagnostic disable-next-line
    local ret = TagList:super({
        output = config.output,
        tags = {},
        style = Style:new(config.style),
        throttle_scroll = config.throttle_scroll,
        inner_view = config.inner_view,
        outer_view = config.outer_view,
        prev_scroll = 0.0,
    })

    ret.tags = ret:get_all_tags()

    ret:setup_signals()

    return ret
end

---Build a new `TagList` widget.
---
---@param ... glacier.widget.taglist.Config
---@return glacier.widget.taglist.TagList
function taglist.mt:__call(...)
    return TagList:new(...)
end

taglist.TagList = TagList

---@diagnostic disable-next-line: param-type-mismatch
return setmetatable(taglist, taglist.mt) --[[@as glacier.widget.taglist]]
