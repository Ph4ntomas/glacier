local cprom = require("cqueues.promise") --[[@as cqueues.promiselib]]

local event_loop = require("glacier.internals.event_loop")

---glacier.timer module
---
---@class glacier.timer
---@field mt metatable This module metatable
---
---@overload fun(...: glacier.timer.Config):glacier.timer.Timer
local timer = { mt = {} }

---Signals sent by timers
---@enum glacier.timer.signals
local signals = {
    ---Emitted when a Timer start or re-start.
    STARTED = "glacier::timer::started",
    ---Emitted when a Timer stops.
    STOPPED = "glacier::timer::stopped",
    ---Emitted when a timeout occurs.
    TIMEOUT = "glacier::timer::timeout",
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

---@class glacier.timer.Config
---
---The signaler to use. If left empty, a new Signaler will be created
---@field signaler? snowcap.signal.Signaler
---The repetition interval for this signaler. Defaults to 1.0.
---@field interval? number
---Whether this timer should repeat. Defaults to true.
---@field repeats? boolean
---Callback to be called on timeout.
---
---The callback will be called along with the [`TimerData`], allowing it to manage the current state
---or emit custom signals in addition to the standard Timeout.
---@field on_timeout? fun(data: glacier.timer.TimerData)

---Internal state of a timer.
---
---@class glacier.timer.TimerData
---@field interval number Amount of time between events.
---@field repeats boolean If true, this timer stop itself after timing out.
---@field signaler snowcap.signal.Signaler

---A simple timer.
---
---`Timer`s can be used to defer some actions, or run some callback periodically.
---
---When the internal timeout expires, a `Timer` will emit
---`glacier.timer.signals.TIMEOUT` and call their on_timeout callback if set.
---If the `Timer` was created without the `repeats` flag set, or via
---`glacier.timer.once()` it will stop after sending the event. Otherwise, the
---`Timer` will wait again in a loop until stopped.
---
---When a timer stop, `glacier.timer.signals.STOPPED` is emitted.
---@class glacier.timer.Timer
---@field private data glacier.timer.TimerData
---@field private on_timeout fun(data: glacier.timer.TimerData)|nil If present, a function to call when the timer timeouts.
---@field private promise cqueues.promise|nil Promise to control the timer.
local Timer = {}

----------------------------
-- Timer's public methods --
----------------------------

---Starts the Timer.
---
---Once started, the timer will periodically emit `timer::timeout`.
---
---@param now? boolean If true, fire an event before sleep.
function Timer:start(now)
    assert(self.promise == nil, "Timer::start() should not be called on a running timer.")

    self.promise = cprom.new()
    event_loop.loop:wrap(function()
        self.data.signaler:emit(signals.STARTED, self)

        if now then
            self:process_timeout()
        end

        local continue = true
        while continue do
            local timeout, restart = promise_sleep(self.data.interval, self.promise)

            if timeout then
                self:process_timeout()
            elseif restart then
                self.promise = restart

                if self.data.repeats then
                    self:emit(signals.STARTED)
                end
            else
                continue = false
            end

            continue = continue and self.data.repeats
        end

        self:emit(signals.STOPPED)
    end)
end

---Stops the Timer.
function Timer:stop()
    if self.promise then
        self.promise:set(true, nil)
        self.promise = nil
    end
end

---Restarts the timer.
---
---This is equivalent of calling stop if the timer was started, followed by a call to start.
---
---@param now? boolean If true, fire an event synchronously.
function Timer:restart(now)
    if self.promise then
        if now then
            self:emit(signals.TIMEOUT)
        end

        self.promise:set(true, cprom.new())
    else
        self:start(now)
    end
end

---Connect to the timer signals.
---
---This is a shorthand for `Timer:signaler():connect()`.
---
---@param sig string
---@param callback any Callback to call when the signal fire.
---@return snowcap.signal.SignalHandle # A handle to disconnect this callback.
function Timer:connect(sig, callback)
    return self.data.signaler:connect(sig, callback)
end

---Access the timer `Signaler`.
---
---@return snowcap.signal.Signaler
function Timer:signaler()
    return self.data.signaler()
end

-----------------------------
-- Timer's private methods --
-----------------------------

---@private
---
---Emit standard signals.
---
---@param sig string
function Timer:emit(sig)
    self.data.signaler:emit(sig, self)
end

---@private
---
---Function called on timeout.
function Timer:process_timeout()
    self:emit(signals.TIMEOUT)

    if self.on_timeout then
        self.on_timeout(self.data)
    end
end

-----------
-- Other --
-----------

---Create a new timer.
---
---@param config glacier.timer.Config
---@return glacier.timer.Timer
function Timer:new(config)
    config = config or {}
    config.repeats = config.repeats == nil and true or config.repeats

    ---@type glacier.timer.Timer
    local ret = {
        data = {
            interval = config.interval or 1.0,
            repeats = config.repeats,
            signaler = config.signaler or require("snowcap.signal").Signaler.new(),
        },
        on_timeout = config.on_timeout,
        promise = nil,
    }
    ret = setmetatable(ret, { __index = Timer })

    return ret
end

---Create a new timer
---
---@param ... glacier.timer.Config
---@return glacier.timer.Timer
function timer.mt:__call(...)
    return Timer:new(...)
end

---Create a timer that will fire only once.
---
---The timer is tstarted before being returned by this function.
---
---@param callback fun(data: glacier.timer.TimerData) Function to call when the timer expires.
---@param timeout number How long to wait before running the callback.
---
---@return glacier.timer.Timer
function timer.once(callback, timeout)
    local ret = Timer:new({
        interval = timeout or 0.0,
        on_timeout = callback,
        repeats = false,
    })

    ret:start()

    return ret
end

---Create a new timer and starts it immediately.
---
---@param ... glacier.timer.Config Configuration options.
---@return glacier.timer.Timer
function timer.started(...)
    local ret = Timer:new(...)

    ret:start()

    return ret
end

timer.Timer = Timer
timer.signals = signals

---@diagnostic disable-next-line: param-type-mismatch
return setmetatable(timer, timer.mt) --[[@as glacier.timer]]
