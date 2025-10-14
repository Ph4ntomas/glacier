local util = {}

---Merge two table recursively
---
---WARNING: No effort were done to support cycle.
function util.merge_table(left, right)
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
            left[k] = util.merge_table(left[k], v)
        end
    end

    return left
end

return util
