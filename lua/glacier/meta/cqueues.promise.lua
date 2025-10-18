---@meta cqueues.promise

---@class cqueues.promiselib
local promise = {}

---@class cqueues.promise
local Promise = {}

---Return "promise" if obj is a promise, nil otherwise
---@param obj cqueues.promise|any Object to test.
---@return string|nil
function promise.type(obj)
    return "promise"
end ---@diagnostic disable-line:unused-local

---Returns a new promise object.
---
---@param f? fun(...): any Optional function to run asynchronously and use as the premise value.
---@param ... any Additional args to call f with.
---@return cqueues.promise
function promise.new(f, ...)
    return {}
end ---@diagnostic disable-line:unused-local

---@enum cqueues.promise.status
local status = {
    fulfilled = "fulfilled",
    rejected = "rejected",
    pending = "pending",
}

---Return the promise status
---
---Status can be:
--- - "pending" => The promise isn't resolved yet.
--- - "fullfiled" => The promise was successfully resolved. Use get to retrieve it's value.
--- - "rejected" => The promise was rejected. Calling get will throw an error.
---@return cqueues.promise.status|nil
function Promise:status()
    return status.pending
end

---Resolve the state of the promise
---
---If ok is true then any subsequent arguments will be returned to promise:get callers. If ok is
---false then an error will be thrown to promise:get callers, with the error value taken from the
---first subsequent argument, if any.
---
---WARNING:
---promise:set can only be called once. Subsequent invocations will throw an error.
---
---@param ok boolean If true, the promise become fullfilled
---@param ... any Additional parameter pack.
function Promise:set(ok, ...) end

---Wait for resolution of the promise object (if unresolved).
---
---Either return the resolved values directly or, if the promise was “rejected”, throw an error.
---
---If timeout is specified, returns nothing if the promise is not resolved within the timeout.
---@param timeout? number Max amount of time to wait, in second.
---@return any|nil # Resolved value if fulfilled, or nil on timeout.
function Promise:get(timeout) end

---Wait for resolution of the promise object or until timeout expires.
---@param timeout? number Max amount of time to wait, in second.
---
---@return cqueues.promise|nil # Returns promise object if the status is no longer pending
---(i.e. “fulfilled” or “rejected”), otherwise nil.
function Promise:wait(timeout) end

---comment
---@return cqueues.condition
function Promise:pollfd()
    return {} --[[@as cqueues.condition]]
end
