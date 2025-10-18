---@class glacier.bar.Child
---@field viewfn? fun():snowcap.widget.WidgetDef
local Child = {}

---Render this child.
---
---@return snowcap.widget.WidgetDef?
---@nodiscard
function Child:view()
    if self.viewfn then
        return self.viewfn()
    end
end

---Update this `Child` internal state.
---
---@param msg any? Message sent to the child.
---@diagnostic disable-next-line:unused-local
function Child:update(msg) end

function Child:__tostring()
    if self.viewfn then
        return ("<bar.Child %s>"):format(tostring(self.viewfn))
    end
end

---Create a child from a view function.
function Child:from_function(viewfn)
    assert(type(viewfn) == "function", "Child:from_function must be called with a view function")

    local child = {
        viewfn = viewfn,
    }

    setmetatable(child, self)
    self.__index = self

    return child
end

return Child
