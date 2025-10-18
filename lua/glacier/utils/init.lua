local utils = {
    timer = require("glacier.utils.timer"),
}

---Merge two table recursively
---
---WARNING: No effort were done to support cycle.
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

return utils
