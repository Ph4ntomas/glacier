---@meta cqueues.condition

cqueues = {}

---@class cqueues.conditionlib
cqueues.condition = {}

---@class cqueues.condition
local Condition = {}

---Return a new condition variable object.
---
---@param lifo? boolean If true, waiting threads are woken in LIFO order.
---@return cqueues.condition
---@nodiscard
function cqueues.condition.new(lifo) end ---@diagnostic disable-line

---Wait on the condition variable.
---
---Additional arguments are yielded to the `cqueues` controller for polling. Passing an integer,
---for example, allows you to effect a timeout. Passing a socket allows you to wait on both the
---condition variable and the socket.
---
---@param ... any Additional arguments to poll.
---@return boolean # Returns true if the thread was woken by the condition variable and false
---otherwise.
---@return any ... # Additional values are returned if they polled as ready
function Condition:wait(...) end

---Signal a condition, wakening one or more waiting threads.
---@param num? integer If specified, a maximum of `n` threads are woken, otherwise all threads
---are woken.
function Condition:signal(num) end
