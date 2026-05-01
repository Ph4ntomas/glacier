---@class glacier.widget.utils
local utils = {}

---View only Program wrapping a simple callback
---@class glacier.widget.utils.View: snowcap.widget.Program
---@field callback fun():snowcap.widget.WidgetDef?
local View = setmetatable({}, { __index = require("snowcap.widget.base").Base })

function View:update(_) end
function View:event(_) end
function View:view()
    return self.callback()
end

---Construct a View from a callback.
---@param callback fun():snowcap.widget.WidgetDef?
---
---@return glacier.widget.utils.View
function utils.view(callback)
    local base = require("snowcap.widget.base").Base.new()
    local ret = setmetatable(base, { __index = View }) --[[@as glacier.widget.utils.View]]

    ret.callback = callback
    return ret
end

return utils
