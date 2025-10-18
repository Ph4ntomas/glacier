local Output = require("pinnacle.output")
local Log = require("pinnacle.log")

local Widget = require("snowcap.widget")
local Operation = require("snowcap.widget.operation")

local Child = require("glacier.bar.child")

---Override a block view.
---
---This function will be called with an array of `snowcap.widget.WidgetDef` (one per child), and
---the `glacier.bar.Style` of the calling bar.
---
---@alias glacier.bar.ViewFn fun(children: snowcap.widget.WidgetDef[], style: glacier.bar.Style): snowcap.widget.WidgetDef

---Function that returns a `snowcap.widget.WidgetDef`.
---
---This type can be used to define stateless widgets.
---@alias glacier.bar.WidgetFn fun(): snowcap.widget.WidgetDef

---glacier.bar module.
---
---@class glacier.bar
---@field mt metatable This module metatable.
---@field first_view? glacier.bar.ViewFn Global override for Bar's first_view function.
---@field center_view? glacier.bar.ViewFn Global override for Bar's center_view function.
---@field last_view? glacier.bar.ViewFn Global override for Bar's last_view function.
---
---@overload fun(...: glacier.bar.Config): glacier.bar.Bar
local bar = { mt = {} }

---Glacier's Bar.
---
---The bar is split into 3 area, called `first`, `center` and `last`. The default configuration put
---the bar at the top of the screen, and render each areas left to right, with the following rules:
--- - first: The area shrink to fit its content, which is left-aligned.
--- - center: The area fill the remaining space. Its content is left aligned.
--- - right: The area shrink to fit its content, which is right-aligned.
---```
--- -------------------------------------------------------
--- | first    |             center             |    last |
--- -------------------------------------------------------
---```
---
---When a new view is needed, the bar does the following:
--- - call the view() function for each of the child widget, filtering out nil value
--- - call the view function for each of the areas, passing the rendered widgets and the bar style.
--- - create a container that fill the whole width (or height, based on orientation) of the screen,
---   and put each area inside.
---
---## Widgets
---The widget can handle stateless widgets, which are defined by a simple function called whenever
---they need to be rendered, or stateful widgets, that derive from `glacier.widget.Base`.
---
---Since stateful widget might have their state change during runtime and they might need to react
---to keyboard input, the bar register callbacks for the following signals:
--- - `glacier.widget.signal.redraw_needed`: When this signal is emitted by a widget, the bars
--- re-render itself.
--- - `glacier.widget.signal.request_focus`: When this signal is emitted by a widget, the bar
--- request exclusive keyboard focus, and that the specific widget be focused by snowcap.
--- - `glacier.widget.signa.request_unfocus`: When this signal is emitted by a widget, the bar
--- request all widget to be unfocused, and set it's exclusive keyboard state to NONE.
---
---## Planned feature:
--- - Bar position and orientation.
--- - Advanced keyboard interaction for widgets.
---
---@class glacier.bar.Bar: snowcap.widget.Program
---@field style glacier.bar.Style Bar style
---@field first_view glacier.bar.ViewFn Function to call to render the first block.
---@field center_view glacier.bar.ViewFn Function to call to render the central block.
---@field last_view glacier.bar.ViewFn Function to call to render the last block.
---@field first glacier.bar.Child[]
---@field center glacier.bar.Child[]
---@field last glacier.bar.Child[]
---@field private handle snowcap.layer.LayerHandle
local Bar = {}

---@class glacier.bar.Style
---@field dimension? integer Dimension of the bar, in pixel.
---@field padding? snowcap.widget.Padding Bar padding.
---@field background_color? snowcap.widget.Color Bar background color.
---@field border? snowcap.widget.Border Bar's border.
---@field spacing? number Spacing between elements.
---@field block_spacing? number Spacing between first/center/last blocks.

---Render a list of children.
---
---@protected
---@param children glacier.bar.Child[]
---@return snowcap.widget.WidgetDef[]
function Bar:view_children(children)
    children = children or {}

    local views = {}

    for _, child in pairs(children) do
        local view = child:view()

        if view then
            table.insert(views, view)
        end
    end

    return views
end

---Default `glacier.bar.ViewFn` to render the first area of the bar.
---
---@param children snowcap.widget.WidgetDef[] A list of already rendered children
---@param style glacier.bar.Style Style of the calling bar.
---@return snowcap.widget.WidgetDef
function bar.default_first_view(children, style)
    return Widget.row({
        height = Widget.length.Fill,
        item_alignment = Widget.alignment.START,
        spacing = style.spacing,
        width = Widget.length.Shrink,
        children = children,
    })
end

---Default `glacier.bar.ViewFn` to render the middle area of the bar.
---
---@param children snowcap.widget.WidgetDef[] A list of already rendered children
---@param style glacier.bar.Style Style of the calling bar.
---@return snowcap.widget.WidgetDef
function bar.default_center_view(children, style)
    return Widget.row({
        height = Widget.length.Fill,
        item_alignment = Widget.alignment.START,
        spacing = style.spacing,
        width = Widget.length.Fill,
        children = children,
    })
end

---Default `glacier.bar.ViewFn` to render the last area of the bar.
---
---@param children snowcap.widget.WidgetDef[] A list of already rendered children
---@param style glacier.bar.Style Style of the calling bar.
---@return snowcap.widget.WidgetDef
function bar.default_last_view(children, style)
    return Widget.row({
        height = Widget.length.Fill,
        item_alignment = Widget.alignment.END,
        spacing = style.spacing,
        width = Widget.length.Shrink,
        children = children,
    })
end

---Render this bar.
---
---@protected
---@return snowcap.widget.WidgetDef
function Bar:view()
    local first_children = self:view_children(self.first)
    local center_children = self:view_children(self.center)
    local last_children = self:view_children(self.last)

    local view = Widget.container({
        width = Widget.length.Fill,
        valign = Widget.alignment.START,
        haligh = Widget.alignment.START,
        padding = self.style.padding,
        style = {
            background_color = self.style.background_color,
            border = {
                width = self.style.border.width,
                color = self.style.border.color,
            },
        },
        child = Widget.row({
            item_alignment = Widget.alignment.START,
            spacing = self.style.block_spacing,
            height = Widget.length.Fixed(self.style.dimension),
            children = {
                self.first_view(first_children, self.style),
                self.center_view(center_children, self.style),
                self.last_view(last_children, self.style),
            },
        }),
    })

    return view
end

---Update a list of children.
---
---@protected
---@param children glacier.bar.Child[] Children to update.
---@param msg any Message to pass to the children.
function Bar:update_children(children, msg)
    children = children or {}

    for _, child in pairs(children) do
        child:update(msg)
    end
end

---Focus this bar.
---
---This function updates the bar's layer keyboard_interactivity.
---@param focus boolean If true, set the layer interactivity to EXCLUSIVE.
function Bar:focus(focus)
    local Layer = require("snowcap.layer")
    local client = require("snowcap.grpc.client").client

    local interactivity = focus and Layer.keyboard_interactivity.EXCLUSIVE
        or Layer.keyboard_interactivity.NONE

    local _, _ = client:snowcap_layer_v1_LayerService_UpdateLayer({
        layer_id = self.handle.id,
        keyboard_interactivity = interactivity,
    })
end

---Update this bar
---
---@protected
---@param msg any The message the bar is getting updated with.
function Bar:update(msg)
    local focusable = require("glacier.widget.operation").focusable

    if msg == nil then
        return
    end

    if msg.operation == focusable.FOCUS then
        self:focus(true)
        Log.warn("Focusing: " .. tostring(msg.id))
        self.handle:operate(Operation.focusable.Focus(msg.id))
        return
    elseif msg.operation == focusable.UNFOCUS then
        self:focus(false)
    end

    self:update_children(self.first, msg)
    self:update_children(self.center, msg)
    self:update_children(self.last, msg)
end

---Show the bar.
---
---This function create a new Layer for this bar.
function Bar:show()
    local Layer = require("snowcap.layer")
    local handle = Layer.new_widget({
        program = self,
        anchor = Layer.anchor.TOP,
        keyboard_interactivity = Layer.keyboard_interactivity.NONE,
        exclusive_zone = self.style.dimension + self.style.padding.top + self.style.padding.bottom,
        layer = Layer.zlayer.TOP,
    })

    if not handle then
        return
    end

    self.handle = handle

    self.handle:on_key_press(function(_, key)
        local focusable = require("glacier.widget.operation").focusable
        local Keys = require("snowcap.input.keys")

        if key == Keys.Escape then
            self:send_message(focusable.Unfocus())
        end
    end)
end

---Send a message to the bar.
---
---This function will call the bar's layer send_message, which will call the bar update function
---then trigger a re-render of the bar.
---
---@param msg? any The message to send to the bar.
function Bar:send_message(msg)
    self.handle:send_message(msg)
end

---Process a list of widgets for this bar.
---
---If the widget inherit from `glacier.widget.Base`, the bar call `glacier.widget.Base:connect()`
---to handle the following signals:
--- - glacier.widget.signal.redraw_needed
--- - glacier.widget.signal.request_focus
--- - glacier.widget.signal.request_unfocus
---
---If the widget is a function, it's wrapped in a `glacier.bar.Child` with a no-op update function.
---
---@protected
---@param children (glacier.widget.Base|glacier.bar.WidgetFn)[]
---@return glacier.bar.Child[]
function Bar:process_children(children)
    children = children or {}

    local processed = {}
    local signals = require("glacier.widget.signal")
    local oper = require("glacier.widget.operation").focusable

    local callbacks = {
        [signals.redraw_needed] = function()
            self:send_message()
        end,
        [signals.request_focus] = function(identifier)
            self:send_message(oper.Focus(identifier))
        end,
        [signals.request_unfocus] = function()
            self:send_message(oper.Unfocus())
        end,
    }

    for _, v in pairs(children) do
        ---@type glacier.bar.Child
        local child = nil

        if type(v) == "function" then
            child = Child:from_function(v)
        elseif type(v) == "table" then ---@diagnostic disable-line
            local widget = v

            local ok, err = pcall(function()
                for k, cb in pairs(callbacks) do
                    widget:connect(k, cb)
                end
            end)

            if not ok then
                Log.error("Failed to register callback for '" .. tostring(child) .. "':" .. err)
            end

            child = widget
        end

        if child ~= nil then
            table.insert(processed, child)
        end
    end

    return processed
end

---Create a new bar.
---
---@param config glacier.bar.Config
function Bar:new(config)
    config = config or {}
    config.style = config.style or {}
    local restore_focus = nil

    if config.output ~= nil then
        restore_focus = Output.get_focused()
        config.output:focus()
    else
        config.output = Output.get_focused()
    end

    ---@type glacier.bar.Config
    local default_config = {
        output = config.output,
        style = {
            dimension = 24,
            background_color = Widget.color.from_rgba(0.15, 0.03, 0.1, 0.65),
            border = { thickness = 0 },
            padding = {
                top = 8,
                right = 8,
                bottom = 8,
                left = 8,
            },
            spacing = 8,
        },
        first_view = bar.first_view or bar.default_first_view,
        center_view = bar.center_view or bar.default_center_view,
        last_view = bar.last_view or bar.default_last_view,
    }

    config = require("glacier.utils").merge_table(default_config, config)

    ---@type glacier.bar.Bar
    ---@diagnostic disable-next-line
    local bar = {
        style = {
            dimension = config.style.dimension,
            background_color = config.style.background_color,
            border = config.style.border,
            padding = config.style.padding,
            spacing = config.style.spacing,
            block_spacing = config.style.block_spacing or config.style.spacing,
        },
        first_view = config.first_view,
        center_view = config.center_view,
        last_view = config.last_view,
        first = {},
        center = {},
        last = {},
    }

    setmetatable(bar, self)
    self.__index = self

    bar.first = bar:process_children(config.first)
    bar.center = bar:process_children(config.center)
    bar.last = bar:process_children(config.last)

    bar:show()

    if restore_focus then
        restore_focus:focus()
    end

    return bar
end

bar.Bar = Bar

---@class glacier.bar.Config
---@field output pinnacle.output.OutputHandle? Handle to the output this bar is meant for.
---@field style? glacier.bar.Style The bar style.
---@field first_view? glacier.bar.ViewFn Function to call to render the first block.
---@field center_view? glacier.bar.ViewFn Function to call to render the central block.
---@field last_view? glacier.bar.ViewFn Function to call to render the last block.
---@field first? (glacier.widget.Base|glacier.bar.WidgetFn)[] A list of widgets to draw on the first area of the bar.
---@field center? (glacier.widget.Base|glacier.bar.WidgetFn)[] A list of widgets to draw in the middle of the bar.
---@field last? (glacier.widget.Base|glacier.bar.WidgetFn)[] A list of widgets to draw on the last area of the bar.

---@param ... glacier.bar.Config
---@return glacier.bar.Bar
function bar.mt:__call(...)
    return Bar:new(...)
end

---@diagnostic disable-next-line:param-type-mismatch
return setmetatable(bar, bar.mt) --[[@as glacier.bar]]
