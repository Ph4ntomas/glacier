local Layer = require("snowcap.layer")
local Widget = require("snowcap.widget")

---Function called when a KeyGrabber receive a KeyPress.
---@alias glacier.keygrabber.KeyPressCallback fun(grabber: glacier.keygrabber.KeyGrabber, mods: snowcap.input.Modifiers, key: snowcap.Key, text: string?)

---Function called when a KeyGrabber receive a KeyRelease.
---@alias glacier.keygrabber.KeyReleaseCallback fun(grabber: glacier.keygrabber.KeyGrabber, mods: snowcap.input.Modifiers, key: snowcap.Key)

---Function called when a KeyGrabber receive a KeyPress.
---@alias glacier.keygrabber.KeyEventCallback fun(grabber: glacier.keygrabber.KeyGrabber, event: snowcap.input.KeyEvent)

---Function called when a KeyGrabber starts.
---@alias glacier.keygrabber.StartCallback fun(grabber: glacier.keygrabber.KeyGrabber)

---Function called when a KeyGrabber stops.
---@alias glacier.keygrabber.StopCallback fun(grabber: glacier.keygrabber.KeyGrabber)

---`glacier.keygrabber` module.
---
---This module introduces an utility class to grab every inputs.
---
---When a KeyGrabber is active, it create a transparent layer with exclusive keyboard interactivity,
---allowing it to receive every inputs that weren't handled by a key binding.
---
---@class glacier.keygrabber
---@field mt metatable
---
---@overload fun(...: glacier.keygrabber.Config): glacier.keygrabber.KeyGrabber
local keygrabber = { mt = {} }

---A keyboard grabbing object.
---
---`KeyGrabber` capture all inputs until stopped. This can be used to implements complex
---interactions that might not be feasible with key bindings alone. As an example, it's used as a
---building block in `glacier.modal`, to implement VI-like behavior.
---
---@class glacier.keygrabber.KeyGrabber: snowcap.widget.Program
---@field private handle snowcap.layer.LayerHandle?
---@field on_key_press? glacier.keygrabber.KeyPressCallback Called when a key press event is received.
---@field on_key_release? glacier.keygrabber.KeyReleaseCallback Called when a key release event is received.
---@field on_key_event? glacier.keygrabber.KeyEventCallback Called on every key events.
---@field on_start? glacier.keygrabber.StartCallback Called when the KeyGrabber start grabbing inputs.
---@field on_stop? glacier.keygrabber.StopCallback Called when the KeyGrabber stops grabbing inputs.
---@field ignore_capture? boolean If true, captured events will be forwarded to `on_key_press`/`on_key_release` callbacks.
local KeyGrabber = {}

---Returns a transparent WidgetDef
---
---@return snowcap.widget.WidgetDef
function KeyGrabber:view()
    return Widget.row({
        style = {
            background_color = Widget.color.from_rgba(0, 0, 0, 0),
        },
        height = Widget.length.Fixed(1.0),
        width = Widget.length.Fixed(1.0),
        children = {},
    })
end

---Update function for KeyGrabber's layer.
---
---Does nothing.
---@param _ any Ignored.
function KeyGrabber:update(_) end

---Start this KeyGrabber
---
---If the KeyGrabber is already running, does nothing. Otherwise, a new layer is created with
---exclusive keyboard interactivity, then the `on_start` callback is called.
function KeyGrabber:start()
    if self.handle then
        return
    end

    local handle = Layer.new_widget({
        layer = Layer.zlayer.OVERLAY,
        exclusive_zone = "respect",
        keyboard_interactivity = Layer.keyboard_interactivity.EXCLUSIVE,
        program = self,
    })

    if not handle then
        require("snowcap.log").error("Could not get a layer handle")

        return
    end

    if self.on_start then
        self.on_start(self)
    end

    handle:on_key_event(function(_, event)
        local captured = event.captured and not self.ignore_capture

        if not captured then
            if event.pressed and self.on_key_press then
                self.on_key_press(self, event.mods, event.key, event.text)
            elseif not event.pressed and self.on_key_release then
                self.on_key_release(self, event.mods, event.key)
            end
        end

        if self.on_key_event then
            self.on_key_event(self, event)
        end
    end)

    self.handle = handle
end

---Stop this KeyGrabber.
---
---Does nothing if the KeyGrabber wasn't already running.
---
---Otherwise, call the `on_stop` callback if present, and close the Layer used to grab inputs.
function KeyGrabber:stop()
    if self.handle then
        if self.on_stop then
            self.on_stop(self)
        end

        self.handle:close()
        self.handle = nil
    end
end

---@class glacier.keygrabber.Config
---@field on_key_press? glacier.keygrabber.KeyPressCallback Called when a key press event is received.
---@field on_key_release? glacier.keygrabber.KeyReleaseCallback Called when a key release event is received.
---@field on_key_event? glacier.keygrabber.KeyEventCallback Called on every key events.
---@field on_start? glacier.keygrabber.StartCallback Called when the KeyGrabber start grabbing inputs.
---@field on_stop? glacier.keygrabber.StopCallback Called when the KeyGrabber stops grabbing inputs.
---@field ignore_capture? boolean If true, captured events will be forwarded to `on_key_press`/`on_key_release` callbacks.

---Create a new keygrabber
---@param config glacier.keygrabber.Config
---@return glacier.keygrabber.KeyGrabber
function KeyGrabber:new(config)
    config = config or {}

    local check_callback = function(name)
        if config[name] then
            assert(
                type(config[name]) == "function",
                "Bad type for callback '"
                    .. name
                    .. "'. Expected function, got "
                    .. type(config[name])
            )
        end
    end

    check_callback("on_key_press")
    check_callback("on_key_release")
    check_callback("on_key_event")
    check_callback("on_start")
    check_callback("on_stop")

    local grabber = {
        on_key_press = config.on_key_press,
        on_key_release = config.on_key_release,
        on_key_event = config.on_key_event,
        on_start = config.on_start,
        on_stop = config.on_stop,
        ignore_capture = config.ignore_capture,
    }

    setmetatable(grabber, self)
    self.__index = self

    return grabber
end

function keygrabber.mt:__call(...)
    return KeyGrabber:new(...)
end

keygrabber.KeyGrabber = KeyGrabber

---@diagnostic disable-next-line: param-type-mismatch
return setmetatable(keygrabber, keygrabber.mt) --[[ @as glacier.keygrabber ]]
