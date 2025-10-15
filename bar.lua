local Output = require("pinnacle.output")
local Log = require("pinnacle.log")

local Widget = require("snowcap.widget")
local Operation = require("snowcap.widget.operation")

--local widget_signals = require("glacier.widget.signal")

local per_output = {}

---@class glacier.bar.Bar: snowcap.widget.Program
---@field style glacier.bars.Style
---@field left glacier.widget.Base[]
---@field center glacier.widget.Base[]
---@field right glacier.widget.Base[]
---@field private handle snowcap.layer.LayerHandle
local Bar = {}

---@class glacier.bars.BarConfig
---@field output pinnacle.output.OutputHandle?
---@field style glacier.bars.Style?
---@field left glacier.widget.Base[]?
---@field center glacier.widget.Base[]?
---@field right glacier.widget.Base[]?

---@class glacier.bars.Style
---@field height integer
---@field margin_bottom integer
---@field padding snowcap.widget.Padding?
---@field background_color snowcap.widget.Color?
---@field border snowcap.widget.Border?

---@protected
function Bar:view_children(children)
    ---@diagnostic disable-next-line:redefined-local
    local children = children or {}

    local views = {}

    for _, child in pairs(children) do
        if child.view ~= nil then
            local view = child:view()

            if view then
                table.insert(views, view)
            end
        end
    end

    return views
end

---@protected
function Bar:view()
    local left_children = self:view_children(self.left)
    local center_children = self:view_children(self.center)
    local right_children = self:view_children(self.right)

    local bar = Widget.container({
        width = Widget.length.Fill,
        valign = Widget.alignment.START,
        haligh = Widget.alignment.START,
        padding = {
            top = 4,
            right = 8,
            bottom = 4,
            left = 8,
        },
        style = {
            background_color = self.style.background_color,
            border = {
                width = self.style.border.width,
                color = self.style.border.color,
            },
        },
        child = Widget.row({
            item_alignment = Widget.alignment.START,
            spacing = 4,
            height = Widget.length.Fixed(self.style.height),
            children = {
                Widget.row({
                    item_alignment = Widget.alignment.START,
                    spacing = 4,
                    width = Widget.length.Shrink,
                    children = left_children
                }),
                Widget.row({
                    item_alignment = Widget.alignment.START,
                    spacing = 4,
                    width = Widget.length.Fill,
                    children = center_children,
                }),
                Widget.row({
                    item_alignment = Widget.alignment.END,
                    spacing = 4,
                    width = Widget.length.Shrink,
                    children = right_children,
                }),
            }
        })
    })

    return bar
end

function Bar:update_children(children, msg)
    ---@diagnostic disable-next-line:redefined-local
    local children = children or {}

    for _, child in pairs(children) do
        if child.update ~= nil then
            child:update(msg)
        end
    end
end

function Bar:focus(focus)
    local Layer = require("snowcap.layer")
    local client = require("snowcap.grpc.client").client

    local interactivity = focus and Layer.keyboard_interactivity.EXCLUSIVE or Layer.keyboard_interactivity.NONE

    local _, _ = client:snowcap_layer_v1_LayerService_UpdateLayer({
        layer_id = self.handle.id,
        keyboard_interactivity = interactivity,
    })
end

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


    self:update_children(self.left, msg)
    self:update_children(self.center, msg)
    self:update_children(self.right, msg)
end

function Bar:show()
    local Layer = require("snowcap.layer")
    local handle = Layer.new_widget({
        program = self,
        anchor = Layer.anchor.TOP,
        keyboard_interactivity = Layer.keyboard_interactivity.NONE,
        exclusive_zone = self.style.height + self.style.margin_bottom,
        layer = Layer.zlayer.TOP,
    })

    if not handle then
        return
    end

    self.handle = handle

    self.handle:on_key_press(function (_, key)
        local focusable = require("glacier.widget.operation").focusable
        local Keys = require("snowcap.input.keys")

        if key == Keys.Escape then
            self:send_message(focusable.Unfocus())
        end
    end)
end

function Bar:send_message(msg)
    self.handle:send_message(msg)
end

local Bars = {}

---Process child widget for this bar
---
---@protected
---@param children glacier.widget.Base[]
function Bar:process_children(children)
    ---@diagnostic disable-next-line:redefined-local
    local children = children or {}
    local processed = {}
    local signals = require("glacier.widget.signal")
    local oper = require("glacier.widget.operation").focusable

    local callbacks = {
        [signals.redraw_needed] = function() self:send_message() end,
        [signals.request_focus] = function(identifier) self:send_message(oper.Focus(identifier)) end,
        [signals.request_unfocus] = function() self:send_message(oper.Unfocus()) end,
    }

    for _, v in pairs(children) do
        local child = nil

        if type(v) == "function" then
            child = {
                view = function(_) v() end
            }
        elseif type(v) == "table" and type(v.view) == "function" then ---@diagnostic disable-line
            child = v

            if child.connect ~= nil then
                local ok, err = pcall(function()
                    for k, cb in pairs(callbacks) do
                        child:connect(k, cb)
                    end
                end)

                if not ok then
                    Log.error("Failed to register callback for '" .. tostring(child) .. "':" .. err)
                end
            end
        end

        if child ~= nil then
            table.insert(processed, child)
        end
    end

    return processed
end

---Create a new bar
---
---@param config glacier.bars.BarConfig
function Bar:new(config)
    --- @diagnostic disable-next-line: redefined-local 
    local config = config or {}
    config.style = config.style or {}
    local restore_focus = nil

    if config.output ~= nil then
        restore_focus = Output.get_focused()
        config.output:focus()
    else
        config.output = Output.get_focused()
    end

    ---@type glacier.bar.Bar
    ---@diagnostic disable-next-line
    local bar = {
        style = {
            height = config.style.height or 40,
            margin_bottom = config.style.margin_bottom or 8,
            background_color = config.style.background_color or Widget.color.from_rgba(0.15, 0.03, 0.1, 0.65),
            border = config.style.border or { thickness = 0 },
        },
        output = config.output,
        left = {},
        center = {},
        right = {},
    }

    setmetatable(bar, self)
    self.__index = self

    bar.left = bar:process_children(config.left)
    bar.center = bar:process_children(config.center)
    bar.right = bar:process_children(config.right)

    bar:show()

    if restore_focus then
        restore_focus:focus()
    end

    return bar
end

function Bars.new(config)
    local bar = Bar:new(config)

    per_output[bar.output.name] = bar

    return bar
end

function Bars.get(output)
    --- @diagnostic disable-next-line: redefined-local 
    local output = output or Output.get_focused()

    return per_output[output.name]
end

return Bars
