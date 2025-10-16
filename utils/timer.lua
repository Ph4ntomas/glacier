local Log = require("pinnacle.log")
local cprom = require("cqueues.promise") --[[@as cqueues.promiselib]]

local cqueue = require("glacier.internals.cqueue")
local signal_table = require("glacier.signal.signal_table")

---glacier.timer module
---
---@class glacier.timer
---@field mt metatable This module metatable
---
---@overload fun(...: glacier.timer.Config):glacier.timer.Timer
local timer = { mt = {} }

---@enum glacier.timer.signals
timer.signals = {
    TIMEOUT = "timer::timeout",
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

---@package
---@class glacier.timer.Inner
---@field signals glacier.signal.SignalTable
---@field promise cqueues.promise|nil Promise to control the timer.
---@field interval number Amount of time between events.
---@field rearm boolean If true, this timer will re-arm itself.
---@field callback fun()|nil If present, a function to call when the timer timeouts.

---A simple timer.
---@class glacier.timer.Timer
---@field private inner glacier.timer.Inner
---@field interval number Amount of time between events.
local Timer = {}

---Start this timer.
---
---@param now? boolean If true, fire an event synchronously.
function Timer:start(now)
    assert(self.inner.promise == nil, "Timer:start() should not be called on a running timer")

    if now then
        self:emit(timer.signals.TIMEOUT)
    end

    self.inner.promise = cprom.new()
    cqueue.loop:wrap(function()
        local continue = true
        while continue do
            local timeout, restart = promise_sleep(self.inner.interval, self.inner.promise)

            if timeout then
                self:emit(timer.signals.TIMEOUT)
                if self.inner.callback then
                    local ok, err = pcall(self.inner.callback)

                    if not ok then
                        Log.error(err)
                    end
                end
            elseif restart then
                self.inner.promise = restart
            else
                continue = false
            end

            continue = continue and self.inner.rearm
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
function Timer:connect(name, callback)
    return self.inner.signals:connect(name, callback)
end

---Emit a signal
---
function Timer:emit(name, ...)
    return self.inner.signals:emit(name, ...)
end

function Timer:disconnect(handle)
    return self.inner.signals:disconnect(handle)
end

function Timer:disconnect_all()
    return self.inner.signals:disconnect_all()
end

---@class glacier.timer.Config
---@field interval? number Timeout in second between events.
---@field once? boolean If true, the timer will act as a simple delay.
---@field callback? fun() Callback to run on timeout.

---@param config glacier.timer.Config
---@return glacier.timer.Timer
function Timer:new(config)
    config = config or {}

    ---@diagnostic disable-next-line:redefined-local
    local timer = {
        inner = {
            signals = signal_table(),
            interval = config.interval or 1.0,
            rearm = not config.once,
            callback = config.callback,
        },
    }

    setmetatable(timer, self)
    self.__index = self

    return timer
end

function timer.mt:__call(config)
    return Timer:new(config)
end

---@diagnostic disable-next-line: param-type-mismatch
return setmetatable(timer, timer.mt)
