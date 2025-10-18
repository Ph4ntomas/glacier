---@meta cqueues

---@class cqueues
---@field VENDOR string
---@field VERSION integer
---@field COMMIT string
local cqueues = {}

---Test if an object is a cqueues controller.
---
---@param obj any Object to test
---@return string? # Return "controller" if obj is a controller. Return nil otherwise.
---@diagnostic disable-next-line:unused-local
function cqueues.type(obj)
    return ""
end

---Add or interpose a cqueues controller class method
---
---@param name string
---@param f fun(...:any):...
---@return (fun(...:any):...)|nil
---@diagnostic disable-next-line:unused-local
function cqueues.interpose(name, f)
    return f
end

---Return the system’s monotonic clock time, usually clock gettime(CLOCK MONOTONIC).
---
---@return number # Monotonic clock time.
function cqueues.monotime()
    return 0.0
end

---Cancel the specified descriptor for all controllers.
---
---@param fd any Descriptor to cancel.
function cqueues.cancel(fd) end

---@param ... any
---@return any ...
function cqueues.poll(...)
    return ...
end

---@param timeout number
function cqueues.sleep(timeout) end

---@return cqueues.cqueue
---@return boolean?
function cqueues.running()
    return {}, --[[@as cqueues.cqueue]]
        true
end

---@diagnostic disable-next-line:unused-local
function cqueues.resume(co) end

---@diagnostic disable-next-line:unused-local
function cqueues.wrap(f) end

---Create a new cqueues object.
---@return cqueues.cqueue
function cqueues.new()
    return {}
end

---@class cqueues.cqueue
local cqueue = {}

---Attach and manage the specified coroutine.
---
---@param co thread # Coroutine to attach.
---@return cqueues.cqueue # Returns the controller.
---@diagnostic disable-next-line:unused-local
function cqueue:attach(co)
    return self
end

---Execute function inside a new coroutine managed by the controller.
---
---@param f fun() Function to execute
---@return cqueues.cqueue # Returns the controller.
---@diagnostic disable-next-line:unused-local
function cqueue:wrap(f)
    return self
end

---Step once through the event queue.
---
---Unless the timeout is explicitly specified as 0, or unless the current thread of execution is a
---cqueues managed coroutine, it suspends the process indefinitely or for the specified timeout
---until a descriptor event or timeout fires.
---
---Step can be called again on errors.
---
---@param timeout? number Maximum time to wait, in seconds.
---@return boolean # Returns true on success.
---@return string? # Error message, if any.
---@return integer? # Error code, if any.
---@return thread? # Lua thread object.
---@return any? # An object that was polled.
---@return integer? # Integer file descriptor.
---@diagnostic disable-next-line:unused-local
function cqueue:step(timeout)
    return true, nil, nil, nil, nil, nil
end

---Invoke cqueues:step in a loop, exiting on error, timeout, or if the event queue is empty.
---
---@param timeout? number
---@return boolean
---@return string?
---@return integer?
---@return thread?
---@return table?
---@return integer?
---@diagnostic disable-next-line:unused-local
function cqueue:loop(timeout)
    return true, nil, nil, nil, nil, nil
end

---Returns an iterator function over errors returned from cqueue:loop.
---
---If cqueues:loop returns successfully because of an empty event queue, or if the timeout expires,
---returns nothing, which terminates any for-loop. ‘timeout’ is cumulative over the entire
---iteration, not simply passed as-is to each invocation of cqueues:loop.
---
---@return any # Return an iterator function over errors returned from cqueue:loop.
function cqueue:errors() end

---Check if the queue is empty.
---
---@return boolean # Returns true if there are no more descriptor or timeout events queued, false otherwise.
function cqueue:empty()
    return true
end

---Check how many coroutines are managed by this queue.
---
---@return integer # Returns a count of managed coroutines.
function cqueue:count()
    return 0
end

---Cancel the specified descriptor for that controller.
---
---@param fd any Descriptor to cancel.
---@diagnostic disable-next-line:unused-local
function cqueue:cancel(fd) end

---A wrapper around pselect which suspends execution of the process until the controller polls
---ready or a signal is delivered.
---
---@param signal integer
---@param ... integer
---@diagnostic disable-next-line:unused-local
function cqueue:pause(signal, ...) end
