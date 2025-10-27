local Image = require("glacier.misc.image")

---Miscellaneous module with some separators.
---@class glacier.separators
local separators = {}

local o = 0
local X = 255

---@class glacier.separators.arrow
separators.arrow = {}

---Right pointing arrow.
---@return glacier.image.AlphaMask
function separators.arrow.right()
    --stylua: ignore start
    local arrow_right_mask = {
        X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,
        X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,
        X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,
        X,X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,
        X,X,X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,
        X,X,X,X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,
        X,X,X,X,X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,
        X,X,X,X,X,X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,
        X,X,X,X,X,X,X,X,X,X,o,o,o,o,o,o,o,o,o,o,
        X,X,X,X,X,X,X,X,X,X,X,o,o,o,o,o,o,o,o,o,
        X,X,X,X,X,X,X,X,X,X,X,X,o,o,o,o,o,o,o,o,
        X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,o,o,o,o,o,
        X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,o,o,o,o,
        X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,o,o,o,
        X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,o,o,
        X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,o,
        X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,
        X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,
        X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,o,
        X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,o,o,
        X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,o,o,o,
        X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,o,o,o,o,
        X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,o,o,o,o,o,
        X,X,X,X,X,X,X,X,X,X,X,X,o,o,o,o,o,o,o,o,
        X,X,X,X,X,X,X,X,X,X,X,o,o,o,o,o,o,o,o,o,
        X,X,X,X,X,X,X,X,X,X,o,o,o,o,o,o,o,o,o,o,
        X,X,X,X,X,X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,
        X,X,X,X,X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,
        X,X,X,X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,
        X,X,X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,
        X,X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,
        X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,
        X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,
        X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,
    }
    --stylua: ignore end

    return Image.alpha({
        x = 20,
        y = 34,
        mask = arrow_right_mask,
    })
end

---Right pointing transparent arrow.
---@return glacier.image.AlphaMask
function separators.arrow.right_inv()
    --stylua: ignore start
    local arrow_right_inv_mask = {
        o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,
        o,o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,
        o,o,o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,
        o,o,o,o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,
        o,o,o,o,o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,
        o,o,o,o,o,o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,
        o,o,o,o,o,o,o,o,X,X,X,X,X,X,X,X,X,X,X,X,
        o,o,o,o,o,o,o,o,o,X,X,X,X,X,X,X,X,X,X,X,
        o,o,o,o,o,o,o,o,o,o,X,X,X,X,X,X,X,X,X,X,
        o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,X,X,X,X,X,
        o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,X,X,X,X,
        o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,X,X,X,
        o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,X,X,
        o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,X,
        o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,
        o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,
        o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,
        o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,
        o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,
        o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,
        o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,X,
        o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,X,X,
        o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,X,X,X,
        o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,X,X,X,X,
        o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,X,X,X,X,X,
        o,o,o,o,o,o,o,o,o,o,X,X,X,X,X,X,X,X,X,X,
        o,o,o,o,o,o,o,o,o,X,X,X,X,X,X,X,X,X,X,X,
        o,o,o,o,o,o,o,o,X,X,X,X,X,X,X,X,X,X,X,X,
        o,o,o,o,o,o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,
        o,o,o,o,o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,
        o,o,o,o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,
        o,o,o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,
        o,o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,
        o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,
    }
    --stylua: ignore end

    return Image.alpha({
        x = 20,
        y = 34,
        mask = arrow_right_inv_mask,
    })
end

---Left pointing arrow.
---@return glacier.image.AlphaMask
function separators.arrow.left()
    --stylua: ignore start
    local arrow_left_mask = {
        o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,
        o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,
        o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,
        o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,X,
        o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,X,X,
        o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,X,X,X,
        o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,X,X,X,X,
        o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,X,X,X,X,X,
        o,o,o,o,o,o,o,o,o,o,X,X,X,X,X,X,X,X,X,X,
        o,o,o,o,o,o,o,o,o,X,X,X,X,X,X,X,X,X,X,X,
        o,o,o,o,o,o,o,o,X,X,X,X,X,X,X,X,X,X,X,X,
        o,o,o,o,o,o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,
        o,o,o,o,o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,
        o,o,o,o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,
        o,o,o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,
        o,o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,
        o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,
        o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,
        o,o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,
        o,o,o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,
        o,o,o,o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,
        o,o,o,o,o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,
        o,o,o,o,o,o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,
        o,o,o,o,o,o,o,o,X,X,X,X,X,X,X,X,X,X,X,X,
        o,o,o,o,o,o,o,o,o,X,X,X,X,X,X,X,X,X,X,X,
        o,o,o,o,o,o,o,o,o,o,X,X,X,X,X,X,X,X,X,X,
        o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,X,X,X,X,X,
        o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,X,X,X,X,
        o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,X,X,X,
        o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,X,X,
        o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,X,
        o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,
        o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,
        o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,
    }
    --stylua: ignore end

    return Image.alpha({
        x = 20,
        y = 34,
        mask = arrow_left_mask,
    })
end

---Left pointing transparent arrow.
---@return glacier.image.AlphaMask
function separators.arrow.left_inv()
    --stylua: ignore start
    local arrow_left_inv_mask = {
        X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,
        X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,o,
        X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,o,o,
        X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,o,o,o,
        X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,o,o,o,o,
        X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,o,o,o,o,o,
        X,X,X,X,X,X,X,X,X,X,X,X,o,o,o,o,o,o,o,o,
        X,X,X,X,X,X,X,X,X,X,X,o,o,o,o,o,o,o,o,o,
        X,X,X,X,X,X,X,X,X,X,o,o,o,o,o,o,o,o,o,o,
        X,X,X,X,X,X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,
        X,X,X,X,X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,
        X,X,X,X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,
        X,X,X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,
        X,X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,
        X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,
        X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,
        X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,
        X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,
        X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,
        X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,
        X,X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,
        X,X,X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,
        X,X,X,X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,
        X,X,X,X,X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,
        X,X,X,X,X,X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,
        X,X,X,X,X,X,X,X,X,X,o,o,o,o,o,o,o,o,o,o,
        X,X,X,X,X,X,X,X,X,X,X,o,o,o,o,o,o,o,o,o,
        X,X,X,X,X,X,X,X,X,X,X,X,o,o,o,o,o,o,o,o,
        X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,o,o,o,o,o,
        X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,o,o,o,o,
        X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,o,o,o,
        X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,o,o,
        X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,o,
        X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,
    }
    --stylua: ignore end

    return Image.alpha({
        x = 20,
        y = 34,
        mask = arrow_left_inv_mask,
    })
end

return separators --[[@as glacier.separators]]
