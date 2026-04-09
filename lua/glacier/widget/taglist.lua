local Posix = require("posix")
local Widget = require("snowcap.widget")

local color = require("glacier.misc.color")

---Glacier's TagList module
---@class glacier.widget.taglist
---@field mt metatable The module metatable
---
---@overload fun(...: glacier.widget.taglist.Config): glacier.widget.TagList
local taglist = { mt = {} }

----------------------
-- Type Definitions --
----------------------

---Render function for Tags.
---@alias glacier.widget.taglist.TagViewCallback fun(tag: glacier.widget.taglist.Tag, style: glacier.widget.taglist.TagStyle): snowcap.widget.WidgetDef?

---Render function for the full list
---@alias glacier.widget.taglist.ListViewCallback fun(tag: snowcap.widget.WidgetDef[], style: glacier.widget.taglist.Style): snowcap.widget.WidgetDef?

---@package
---@class glacier.widget.taglist.ActiveChanged
---@field handle pinnacle.tag.TagHandle
---@field active boolean

---TagList's events
---@class glacier.widget.taglist.Event
---@field toggle? pinnacle.tag.TagHandle
---@field switch? pinnacle.tag.TagHandle
---@field enter? pinnacle.tag.TagHandle
---@field exit? pinnacle.tag.TagHandle
---@field next? {}
---@field prev? {}
---@field small_scroll? {}
---@field active_changed? glacier.widget.taglist.ActiveChanged

---Taglist's messages.
---@class glacier.widget.taglist.Message
---@field id integer
---@field event glacier.widget.taglist.Event
local Message = {}

---Single Tag's appearance.
---@class glacier.widget.taglist.TagStyle
---@field bg_color? snowcap.widget.Color
---@field fg_color? snowcap.widget.Color
---@field font? snowcap.widget.Font
---@field pixels? number
---@field border? snowcap.widget.Border
---@field padding? snowcap.widget.Padding
local TagStyle = {}

---TagList's appearance.
---@class glacier.widget.taglist.Style: glacier.widget.taglist.TagStyle
---@field active? glacier.widget.taglist.TagStyle
---@field inactive? glacier.widget.taglist.TagStyle
---@field spacing? number
---@field hover_transform? fun(style: glacier.widget.taglist.TagStyle): glacier.widget.taglist.TagStyle
local Style = {}

---Single Tag.
---@class glacier.widget.taglist.Tag
---@field name string
---@field handle pinnacle.tag.TagHandle
---@field active boolean
---@field hovered boolean

---TagList's configuration.
---@class glacier.widget.taglist.Config
---@field output pinnacle.output.OutputHandle
---@field style? glacier.widget.taglist.Style
---@field tag_view_callback? glacier.widget.taglist.TagViewCallback
---@field list_view_callback? glacier.widget.taglist.ListViewCallback

---TagList widget.
---
---@class glacier.widget.TagList: snowcap.widget.Program
---@field output pinnacle.output.OutputHandle
---@field tag_view_callback glacier.widget.taglist.TagViewCallback
---@field list_view_callback glacier.widget.taglist.ListViewCallback
---@field private _style glacier.widget.taglist.Style
---@field private _tags glacier.widget.taglist.Tag[]
---@field private _last_scroll number
---@field private _throttle_scroll number
local TagList = setmetatable({}, { __index = require("snowcap.widget.base").Base })

----------------------
-- Module functions --
----------------------

---Default TagList's appearance.
---
---@param style? glacier.widget.taglist.Style
---@return glacier.widget.taglist.Style
function taglist.default_style(style)
    ---@type glacier.widget.taglist.Style
    return require("glacier.utils").merge_table({
        fg_color = color.from_hex("#CCCCCC"),
        font = {
            family = Widget.font.family.Monospace,
            weight = Widget.font.weight.BOLD,
        },
        border = {
            width = 0.0,
        },
        padding = {
            top = 2.0,
            bottom = 2.0,
            left = 8.0,
            right = 8.0,
        },
        spacing = 0.,
        active = {
            bg_color = color.from_hex("#33991A"),
        },
        inactive = {
            bg_color = color.from_hex("#666666"),
        },
    }, style)
end

---Default Tag render function.
---
---@param tag glacier.widget.taglist.Tag
---@param style glacier.widget.taglist.TagStyle
---@return snowcap.widget.WidgetDef?
function taglist.default_tag_view(tag, style)
    return Widget.container({
        child = Widget.text({
            text = tag.name,
            height = Widget.length.Fill,
            width = Widget.length.Shrink,
            valign = Widget.alignment.CENTER,
            style = style:to_text(),
        }),
        padding = style.padding,
        style = style:to_container(),
    })
end

---Default TagList render function.
---
---@param children snowcap.widget.WidgetDef[]
---@param style glacier.widget.taglist.Style
---@return snowcap.widget.WidgetDef?
function taglist.default_list_view(children, style)
    return Widget.row({
        children = children,
        height = Widget.length.Fill,
        width = Widget.length.shrink,
        spacing = style.spacing,
    })
end

---Default hover transform.
---
---@param amount number
---@return fun(style: glacier.widget.taglist.TagStyle): glacier.widget.taglist.TagStyle
function taglist.brighten_background(amount)
    return function(style)
        local clamp = function(value, min, max)
            if value < min then
                return min
            elseif value > max then
                return max
            else
                return value
            end
        end
        local background = style.bg_color

        if background then
            local red = background.red or 0.0
            local green = background.green or 0.0
            local blue = background.blue or 0.0

            background.red = clamp(red * amount, 0.0, 1.0)
            background.green = clamp(green * amount, 0.0, 1.0)
            background.blue = clamp(blue * amount, 0.0, 1.0)
        end

        style.bg_color = background
        return style
    end
end

---@package
---Get all tags tied to an output.
---
---@param output pinnacle.output.OutputHandle
---@return glacier.widget.taglist.Tag[]
local function get_all_tags(output)
    local tag_handles = output:tags()

    local requests = {}
    for i, handle in pairs(tag_handles) do
        requests[i] = function()
            return {
                name = handle:name(),
                active = handle:active(),
            }
        end
    end

    local tags = require("snowcap.util").batch(requests)

    ---@type glacier.widget.taglist.Tag[]
    local tag_list = {}
    for i, tag in pairs(tags) do
        table.insert(tag_list, {
            handle = tag_handles[i],
            name = tag.name,
            active = tag.active,
            hovered = false,
        })
    end

    return tag_list
end

---@package
---
---@return number
local function _now()
    local sec, nsec = Posix.clock_gettime(0)
    return sec + nsec / 10 ^ 9
end

----------------------
-- Message function --
----------------------

---@param id integer
---@param handle pinnacle.tag.TagHandle
---@return glacier.widget.taglist.Message
function Message.toggle(id, handle)
    ---@type glacier.widget.taglist.Message
    return {
        id = id,
        event = {
            toggle = handle,
        },
    }
end

---@param id integer
---@param handle pinnacle.tag.TagHandle
---@return glacier.widget.taglist.Message
function Message.switch(id, handle)
    ---@type glacier.widget.taglist.Message
    return {
        id = id,
        event = {
            switch = handle,
        },
    }
end

---@param id integer
---@param handle pinnacle.tag.TagHandle
---@return glacier.widget.taglist.Message
function Message.enter(id, handle)
    ---@type glacier.widget.taglist.Message
    return {
        id = id,
        event = {
            enter = handle,
        },
    }
end

---@param id integer
---@param handle pinnacle.tag.TagHandle
---@return glacier.widget.taglist.Message
function Message.exit(id, handle)
    ---@type glacier.widget.taglist.Message
    return {
        id = id,
        event = {
            exit = handle,
        },
    }
end

---@param id integer
---@param handle pinnacle.tag.TagHandle
---@return glacier.widget.taglist.Message
function Message.active_changed(id, handle, active)
    ---@type glacier.widget.taglist.Message
    return {
        id = id,
        event = {
            active_changed = {
                handle = handle,
                active = active,
            },
        },
    }
end

----------------------
-- TagStyle methods --
----------------------

---Create a container style from this TagStyle
---@return snowcap.widget.container.Style
function TagStyle:to_container()
    ---@type snowcap.widget.container.Style
    return {
        text_color = self.fg_color,
        background = self.bg_color and Widget.background.Color(self.bg_color) or nil,
        border = self.border,
    }
end

---Create a text style from this TagStyle
function TagStyle:to_text()
    ---@type snowcap.widget.text.Style
    return {
        color = self.fg_color,
        pixels = self.pixels,
        font = self.font,
    }
end

-----------------------
-- TagStyle lifetime --
-----------------------

---@package
---Initialize style
---
---@param style glacier.widget.taglist.TagStyle
---@return glacier.widget.taglist.TagStyle
function TagStyle.new(style)
    style = style or {}

    return setmetatable(style, { __index = TagStyle }) --[[@as glacier.widget.taglist.TagStyle]]
end

-------------------
-- Style methods --
-------------------

---Return a `TagStyle`, based on a tag active state.
---@param active boolean
---@return glacier.widget.taglist.TagStyle
function Style:get(active)
    local deep_copy = require("snowcap.util").deep_copy
    local merge_table = require("glacier.utils").merge_table

    ---@type glacier.widget.taglist.TagStyle
    local style = deep_copy({
        fg_color = self.fg_color,
        bg_color = self.bg_color,
        border = self.border,
        padding = self.padding,
        font = self.font,
    })

    if active then
        style = merge_table(style, self.active)
    else
        style = merge_table(style, self.inactive)
    end

    return TagStyle.new(style)
end

--------------------
-- Style lifetime --
--------------------

---@package
---Initialize style
---
---@param style glacier.widget.taglist.Style
---@return glacier.widget.taglist.Style
function Style.new(style)
    return setmetatable(style, { __index = Style }) --[[@as glacier.widget.taglist.Style]]
end

----------------------------
-- TagList public methods --
----------------------------

-----------------------------
-- TagList private methods --
-----------------------------

---@private
---
---@return snowcap.widget.WidgetDef[]
function TagList:view_tags()
    ---@type snowcap.widget.WidgetDef[]
    local widgets = {}
    local style = self._style
    local view_callback = self.tag_view_callback or taglist.default_tag_view

    for _, tag in pairs(self._tags) do
        local tag_style = style:get(tag.active)
        if tag.hovered and style.hover_transform then
            tag_style = style.hover_transform(tag_style)
        end

        local tag_widget = view_callback(tag, tag_style)
        if tag_widget then
            table.insert(
                widgets,
                Widget.mouse_area({
                    child = tag_widget,
                    on_release = Message.switch(self:id(), tag.handle),
                    on_right_release = Message.toggle(self:id(), tag.handle),
                    on_enter = Message.enter(self:id(), tag.handle),
                    on_exit = Message.exit(self:id(), tag.handle),
                })
            )
        end
    end

    return widgets
end

---@private
---
---@param event snowcap.widget.mouse_area.ScrollEvent
---@return glacier.widget.taglist.Message
function TagList:on_scroll(event)
    local x = 0.0
    local y = 0.0

    if event.lines then
        x = event.lines.x
        y = event.lines.y
    elseif event.pixels then
        x = event.pixels.x
        y = event.pixels.y
    end

    x = x or 0.0
    y = y or 0.0

    local delta = math.abs(x) > math.abs(y) and x or y

    ---@type glacier.widget.taglist.Event
    local msg_event = {}

    if delta > 0.5 then
        msg_event.next = {}
    elseif delta < -0.5 then
        msg_event.prev = {}
    else
        msg_event.small_scroll = {}
    end

    ---@type glacier.widget.taglist.Message
    return {
        id = self:id(),
        event = msg_event,
    }
end

---@private
function TagList:set_hover_for(handle, hover)
    for _, tag in pairs(self._tags) do
        if tag.handle.id == handle.id then
            tag.hovered = hover
            return
        end
    end
end

---@private
---@return integer?
function TagList:find_active_idx()
    for i, tag in ipairs(self._tags) do
        if tag.active then
            return i
        end
    end
end

---@private
function TagList:focus_next_tag()
    local idx = self:find_active_idx()

    if not idx or idx == #self._tags then
        idx = 1
    else
        idx = idx + 1
    end

    self._tags[idx].handle:switch_to()
end

---@private
function TagList:focus_prev_tag()
    local idx = self:find_active_idx()

    if not idx or idx == 1 then
        idx = #self._tags
    else
        idx = idx - 1
    end

    self._tags[idx].handle:switch_to()
end

---@private
---@param msg glacier.widget.taglist.Message|any
---@return glacier.widget.taglist.Event?
function TagList:get_message_event(msg)
    if msg and msg.id == self:id() then
        return msg.event
    end

    return nil
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
function TagList:view()
    if #self._tags == 0 then
        return
    end

    local children = self:view_tags()

    if not children or #children == 0 then
        return
    end

    local list_view = self.list_view_callback or taglist.default_list_view
    local list = list_view(children, self._style)

    if not list then
        return
    end

    return Widget.mouse_area({
        child = list,
        on_scroll = function(event)
            return self:on_scroll(event)
        end,
    })
end

---Updates this widget program with the received message.
---@param msg any|glacier.widget.prompt.Message
function TagList:update(msg)
    local event = self:get_message_event(msg)

    if not event then
        return
    end

    if event.prev or event.next then
        local now = _now()
        local diff = now - self._last_scroll

        if diff < self._throttle_scroll then
            return
        else
            self._last_scroll = now
        end
    end

    if event.switch then
        event.switch:switch_to()
    elseif event.toggle then
        event.toggle:toggle_active()
    elseif event.enter then
        self:set_hover_for(event.enter, true)
    elseif event.exit then
        self:set_hover_for(event.exit, true)
    elseif event.next then
        self:focus_next_tag()
    elseif event.prev then
        self:focus_prev_tag()
    elseif event.active_changed then
        local handle = event.active_changed.handle
        local active = event.active_changed.active
        for _, tag in pairs(self._tags) do
            if tag.handle.id == handle.id then
                tag.active = active
                break
            end
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
function TagList:event(event)
    if event.created then
        self._tags = get_all_tags(self.output)

        local Tag = require("pinnacle.tag")
        local StdSig = require("snowcap.widget.signal")

        local sig_handle = Tag.connect_signal({
            active = function(handle, active)
                self:emit(StdSig.send_message, Message.active_changed(self:id(), handle, active))
            end,
        })

        self._sig_handle = sig_handle
        self:emit(StdSig.redraw_needed)
    elseif event.closing then
        self._sig_handle:disconnect_all()
    end
end

-----------
-- Other --
-----------

---Create a new TagList widget,
---
---@param config glacier.widget.taglist.Config
---@return glacier.widget.TagList
function TagList:new(config)
    config = config or {}
    config.style = config.style or taglist.default_style()

    local base = require("snowcap.widget.base").Base.new()
    local ret = setmetatable(base, {
        __index = TagList,
    }) --[[@as glacier.widget.TagList]]

    ret.output = config.output
    ret.tag_view_callback = config.tag_view_callback
    ret.list_view_callback = config.list_view_callback

    ret._style = Style.new(config.style)
    ret._tags = {}
    ret._throttle_scroll = 0.05
    ret._last_scroll = 0.0

    return ret
end

---Create a new TagList widget
---
---@param ... glacier.widget.taglist.Config
---@return glacier.widget.TagList
function taglist.mt:__call(...)
    return TagList:new(...)
end

---@diagnostic disable-next-line:param-type-mismatch
return setmetatable(taglist, taglist.mt) --[[@as glacier.widget.taglist]]
