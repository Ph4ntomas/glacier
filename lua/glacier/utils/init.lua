---Glacier utility module
---
---@class glacier.utils
local utils = {
    timer = require("glacier.utils.timer"),
}

---Merge two table recursively
---
---WARNING: No effort were done to support cycle.
---@generic T
---@param left T
---@param right T
---@return T
function utils.merge_table(left, right)
    if left == nil then
        return right
    elseif right == nil then
        return left
    end

    if type(left) ~= type(right) then
        return right
    end

    if type(left) ~= "table" then
        return right
    else
        for k, v in pairs(right) do
            left[k] = utils.merge_table(left[k], v)
        end
    end

    return left
end

---Weak wrapper around some data.
---@class glacier.utils.Weak<T>
---@field data T
local Weak = {}

---Create a new Weak<T>
---
---@generic T
---@param data T
---@return glacier.utils.Weak<T>
function Weak:new(data)
    return setmetatable({ data = data }, { __index = Weak, __mode = "kv" })
end

---Retrieve the value
---
---@generic T
---@return T?
function Weak:get()
    return self.data
end

---Check if the value is still alive
---
---@return boolean
function Weak:is_alive()
    return self.data ~= nil
end

---Wrap a reference in a `Weak`
---
---@generic T
---@param data T
---@return glacier.utils.Weak<T>
function utils.weak(data)
    return Weak:new(data)
end

utils.Weak = Weak

return utils
