local cprom = require("cqueues.promise") --[[@as cqueues.promiselib]]

local event_loop = require("glacier.internals.event_loop")
local signal_table = require("glacier.signal.signal_table")

---glacier.timer module
---
---@class glacier.timer
---@field mt metatable This module metatable
---
---@overload fun(...: glacier.timer.Config):glacier.timer.Timer
local timer = { mt = {} }

---Signals emitted by timers.
---@enum glacier.timer.signals
timer.signals = {
    ---Emitted when the timer starts.
    STARTED = "timer::started",
    ---Emitted when the timer timeout.
    TIMEOUT = "timer::timeout",
    ---Emitted when the timer stop.
    STOPPED = "timer::stopped",
}

---Cancellable sleep function.
---
---@param timeout number
---@param promise cqueues.promise
---@return boolean # Return true if the timeout woke us up, false if the function was cancelled.
---@return cqueues.promise? # If set, the timer should be immediately restarted using this promise instead
local function promise_sleep(timeout, promise)
    local ret = promise:wait(timeout)

    if ret then
        return false, promise:get(0)
    end

    return true, nil
end

---Internal state of a timer.
---
---@package
---@class glacier.timer.Inner
---@field signals glacier.signal.SignalTable
---@field promise cqueues.promise|nil Promise to control the timer.
---@field interval number Amount of time between events.
---@field once boolean If true, this timer stop itself after timing out.
---@field callback fun()|nil If present, a function to call when the timer timeouts.

---A simple timer.
---
---`Timer`s can be used to defer some actions, or run some callback periodically.
---
---When the internal timeout expires, a `Timer` will first run their associated callback, then
---emit `glacier.timer.signals.TIMEOUT` without arguments. If the `Timer` was created with the
---`once` flag, or via `glacier.timer.once()` it will stop after sending the event. Otherwise,
---the `Timer` will wait again in a loop until stopped.
---
---When a timer stop, `glacier.timer.signals.STOPPED` is emitted.
---@class glacier.timer.Timer
---@field private inner glacier.timer.Inner Internal state.
local Timer = {}

---Start this timer.
---
---Once started, the timer will periodically emit `timer::timeout`.
---
---@param now? boolean If true, fire an event before sleep.
function Timer:start(now)
    assert(self.inner.promise == nil, "Timer:start() should not be called on a running timer")

    self.inner.promise = cprom.new()
    event_loop.loop:wrap(function()
        self:emit(timer.signals.STARTED)

        if now then
            self:emit(timer.signals.TIMEOUT)
        end

        local continue = true
        while continue do
            local timeout, restart = promise_sleep(self.inner.interval, self.inner.promise)

            if timeout then
                self:emit(timer.signals.TIMEOUT)
            elseif restart then
                self.inner.promise = restart

                --No sense in sending a `started` event if we're not looping.
                if not self.inner.once then
                    self:emit(timer.signals.STARTED)
                end
            else
                continue = false
            end

            continue = continue and not self.inner.once
        end

        self:emit(timer.signals.STOPPED)
    end)
end

---Stop this timer
function Timer:stop()
    if self.inner.promise then
        self.inner.promise:set(true, nil)
        self.inner.promise = nil
    end
end

---Restart this timer
---
---This is equivalent of calling stop if the timer was started, followed by a call to start.
---
---@param now? boolean If true, fire an event synchronously.
function Timer:restart(now)
    if self.inner.promise then
        if now then
            self:emit(timer.signals.TIMEOUT)
        end

        self.inner.promise:set(true, cprom.new())
    else
        self:start(now)
    end
end

---Connect to this timer signals
---
---@param name glacier.timer.signals
---@param callback any Callback to call when the signal is emitted.
---@return glacier.signal.SignalHandle # A handle to disconnect this callback.
function Timer:connect(name, callback)
    return self.inner.signals:connect(name, callback)
end

---Emit a signal.
---
---@param
function Timer:emit(name, ...)
    return self.inner.signals:emit(name, self, ...)
end

---Disconnect a signal callback
---
---@param handle glacier.signal.SignalHandle
function Timer:disconnect(handle)
    self.inner.signals:disconnect(handle)
end

---Disconnect all listener.
function Timer:disconnect_all()
    self.inner.signals:disconnect_all()
end

---Timer configuration.
---@class glacier.timer.Config
---@field timeout? number Timeout in second between events.
---@field once? boolean If true, the timer will act as a simple delay.
---@field callback? fun() Callback to run on timeout.

---Create a new timer, according to the configuration.
---
---If `config` is or nil, the default is a timer that will trigger every seconds.
---
---@param config glacier.timer.Config
---@return glacier.timer.Timer
function Timer:new(config)
    config = config or {}

    ---@type glacier.timer.Timer
    local ret = { ---@diagnostic disable-line:redefined-local
        inner = {
            signals = signal_table(),
            interval = config.timeout or 1.0,
            once = config.once,
            callback = config.callback,
        },
    }

    setmetatable(ret, self)
    self.__index = self

    if config.callback then
        ret:connect(timer.signals.TIMEOUT, config.callback)
    end

    return ret
end

---Create a new timer.
---
---@param ... glacier.timer.Config Configuration option
---@return glacier.timer.Timer
function timer.mt:__call(...)
    return Timer:new(...)
end

---Create a timer that will fire only once.
---
---The timer is started before being returned by this function.
---
---@param timeout number How long to wait before running `function`
---@param callback fun(timer) Function to call when the internal timer expires.
---@return glacier.timer.Timer
function timer.once(timeout, callback)
    local ret = Timer:new({
        timeout = timeout or 0.0,
        callback = callback,
        once = true,
    })

    ret:start()

    return ret
end

---Create a new timer and start it before returning.
---
---@param ... glacier.timer.Config Timer configuration option.
---@return glacier.timer.Timer
function timer.started(...)
    local ret = Timer:new(...)

    ret:start()

    return ret
end

timer.Timer = Timer

---@diagnostic disable-next-line: param-type-mismatch
return setmetatable(timer, timer.mt)
