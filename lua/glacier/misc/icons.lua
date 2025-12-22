local Image = require("glacier.misc.image")

---@class glacier.icons
local icons = {}

local o = 0
local X = 255

---@class glacier.icons.menu
icons.menu = {}

---@return glacier.image.AlphaMask
function icons.menu.menu_indicator()
    --stylua: ignore start
    local menu_indicator_mask = {
        o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,
        o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,
        X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,
        X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,
        X,X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,
        o,X,X,X,X,X,o,o,o,o,o,o,o,o,o,o,
        o,o,X,X,X,X,X,o,o,o,o,o,o,o,o,o,
        o,o,o,X,X,X,X,X,o,o,o,o,o,o,o,o,
        o,o,o,o,X,X,X,X,X,o,o,o,o,o,o,o,
        o,o,o,o,o,X,X,X,X,X,o,o,o,o,o,o,
        o,o,o,o,o,o,X,X,X,X,X,o,o,o,o,o,
        o,o,o,o,o,o,o,X,X,X,X,X,o,o,o,o,
        o,o,o,o,o,o,o,o,X,X,X,X,X,o,o,o,
        o,o,o,o,o,o,o,o,o,X,X,X,X,X,o,o,
        o,o,o,o,o,o,o,o,o,o,X,X,X,X,X,o,
        o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,X,
        o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,X,
        o,o,o,o,o,o,o,o,o,o,X,X,X,X,X,o,
        o,o,o,o,o,o,o,o,o,X,X,X,X,X,o,o,
        o,o,o,o,o,o,o,o,X,X,X,X,X,o,o,o,
        o,o,o,o,o,o,o,X,X,X,X,X,o,o,o,o,
        o,o,o,o,o,o,X,X,X,X,X,o,o,o,o,o,
        o,o,o,o,o,X,X,X,X,X,o,o,o,o,o,o,
        o,o,o,o,X,X,X,X,X,o,o,o,o,o,o,o,
        o,o,o,X,X,X,X,X,o,o,o,o,o,o,o,o,
        o,o,X,X,X,X,X,o,o,o,o,o,o,o,o,o,
        o,X,X,X,X,X,o,o,o,o,o,o,o,o,o,o,
        X,X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,
        X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,
        X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,
        o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,
        o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,
    }
    --stylua: ignore end

    return Image.alpha({
        x = 16,
        y = 32,
        mask = menu_indicator_mask,
    })
end

---@class glacier.icons.radio
icons.radio = {}

function icons.radio.selected()
    --stylua: ignore start
    local radio_mask = {
        o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,
        o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,
        o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,
        o,o,o,o,o,o,o,o,o,o,X,X,X,X,X,X,X,X,X,X,X,X,o,o,o,o,o,o,o,o,o,o,
        o,o,o,o,o,o,o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,o,o,o,o,o,o,
        o,o,o,o,o,o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,o,o,o,o,o,
        o,o,o,o,o,o,X,X,X,X,X,X,o,o,o,o,o,o,o,o,X,X,X,X,X,X,o,o,o,o,o,o,
        o,o,o,o,o,X,X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,X,o,o,o,o,o,
        o,o,o,o,X,X,X,X,X,o,o,o,X,X,X,X,X,X,X,X,o,o,o,X,X,X,X,X,o,o,o,o,
        o,o,o,o,X,X,X,X,o,o,o,X,X,X,X,X,X,X,X,X,X,o,o,o,X,X,X,X,o,o,o,o,
        o,o,o,X,X,X,X,o,o,o,X,X,X,X,X,X,X,X,X,X,X,X,o,o,o,X,X,X,X,o,o,o,
        o,o,o,X,X,X,X,o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,X,X,X,X,o,o,o,
        o,o,o,X,X,X,o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,X,X,X,o,o,o,
        o,o,X,X,X,X,o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,X,X,X,X,o,o,
        o,o,X,X,X,X,o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,X,X,X,X,o,o,
        o,o,X,X,X,X,o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,X,X,X,X,o,o,
        o,o,X,X,X,X,o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,X,X,X,X,o,o,
        o,o,X,X,X,X,o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,X,X,X,X,o,o,
        o,o,X,X,X,X,o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,X,X,X,X,o,o,
        o,o,o,X,X,X,o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,X,X,X,o,o,o,
        o,o,o,X,X,X,X,o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,X,X,X,X,o,o,o,
        o,o,o,X,X,X,X,o,o,o,X,X,X,X,X,X,X,X,X,X,X,X,o,o,o,X,X,X,X,o,o,o,
        o,o,o,o,X,X,X,X,o,o,o,X,X,X,X,X,X,X,X,X,X,o,o,o,X,X,X,X,o,o,o,o,
        o,o,o,o,X,X,X,X,X,o,o,o,X,X,X,X,X,X,X,X,o,o,o,X,X,X,X,X,o,o,o,o,
        o,o,o,o,o,X,X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,X,o,o,o,o,o,
        o,o,o,o,o,o,X,X,X,X,X,X,o,o,o,o,o,o,o,o,X,X,X,X,X,X,o,o,o,o,o,o,
        o,o,o,o,o,o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,o,o,o,o,o,
        o,o,o,o,o,o,o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,o,o,o,o,o,o,
        o,o,o,o,o,o,o,o,o,o,X,X,X,X,X,X,X,X,X,X,X,X,o,o,o,o,o,o,o,o,o,o,
        o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,
        o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,
        o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,
    }
    --stylua: ignore end

    return Image.alpha({
        x = 32,
        y = 32,
        mask = radio_mask,
    })
end

function icons.radio.unselected()
    --stylua: ignore start
    local radio_mask = {
        o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,
        o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,
        o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,
        o,o,o,o,o,o,o,o,o,o,X,X,X,X,X,X,X,X,X,X,X,X,o,o,o,o,o,o,o,o,o,o,
        o,o,o,o,o,o,o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,o,o,o,o,o,o,
        o,o,o,o,o,o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,o,o,o,o,o,
        o,o,o,o,o,o,X,X,X,X,X,X,o,o,o,o,o,o,o,o,X,X,X,X,X,X,o,o,o,o,o,o,
        o,o,o,o,o,X,X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,X,o,o,o,o,o,
        o,o,o,o,X,X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,X,o,o,o,o,
        o,o,o,o,X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,o,o,o,o,
        o,o,o,X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,o,o,o,
        o,o,o,X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,o,o,o,
        o,o,o,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,o,o,o,
        o,o,X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,o,o,
        o,o,X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,o,o,
        o,o,X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,o,o,
        o,o,X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,o,o,
        o,o,X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,o,o,
        o,o,X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,o,o,
        o,o,o,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,o,o,o,
        o,o,o,X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,o,o,o,
        o,o,o,X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,o,o,o,
        o,o,o,o,X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,o,o,o,o,
        o,o,o,o,X,X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,X,o,o,o,o,
        o,o,o,o,o,X,X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,X,o,o,o,o,o,
        o,o,o,o,o,o,X,X,X,X,X,X,o,o,o,o,o,o,o,o,X,X,X,X,X,X,o,o,o,o,o,o,
        o,o,o,o,o,o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,o,o,o,o,o,
        o,o,o,o,o,o,o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,o,o,o,o,o,o,
        o,o,o,o,o,o,o,o,o,o,X,X,X,X,X,X,X,X,X,X,X,X,o,o,o,o,o,o,o,o,o,o,
        o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,
        o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,
        o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,
    }
    --stylua: ignore end

    return Image.alpha({
        x = 32,
        y = 32,
        mask = radio_mask,
    })
end

function icons.radio.select(value)
    if value then
        return icons.radio.selected()
    else
        return icons.radio.unselected()
    end
end

---@class glaicer.icons.checkbox
icons.checkbox = {}

function icons.checkbox.selected()
    --stylua: ignore start
    local checkbox_mask = {
        o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,
        o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,
        o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,
        o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,
        o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,
        o,o,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,o,o,
        o,o,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,o,o,
        o,o,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,o,o,
        o,o,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,o,o,
        o,o,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,o,o,X,X,X,o,o,
        o,o,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,o,o,X,X,X,o,o,
        o,o,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,o,o,X,X,X,o,o,
        o,o,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,o,o,o,X,X,X,o,o,
        o,o,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,o,o,o,o,X,X,X,o,o,
        o,o,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,X,o,o,o,o,o,X,X,X,o,o,
        o,o,X,X,X,o,o,X,X,o,o,o,o,o,o,o,o,X,X,X,X,o,o,o,o,o,o,X,X,X,o,o,
        o,o,X,X,X,o,o,X,X,X,o,o,o,o,o,o,X,X,X,X,o,o,o,o,o,o,o,X,X,X,o,o,
        o,o,X,X,X,o,o,X,X,X,X,o,o,o,o,X,X,X,X,o,o,o,o,o,o,o,o,X,X,X,o,o,
        o,o,X,X,X,o,o,o,X,X,X,X,o,o,X,X,X,X,o,o,o,o,o,o,o,o,o,X,X,X,o,o,
        o,o,X,X,X,o,o,o,o,X,X,X,X,X,X,X,X,o,o,o,o,o,o,o,o,o,o,X,X,X,o,o,
        o,o,X,X,X,o,o,o,o,o,X,X,X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,X,X,X,o,o,
        o,o,X,X,X,o,o,o,o,o,o,X,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,o,o,
        o,o,X,X,X,o,o,o,o,o,o,o,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,o,o,
        o,o,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,o,o,
        o,o,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,o,o,
        o,o,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,o,o,
        o,o,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,o,o,
        o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,
        o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,
        o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,
        o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,
        o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,
    }
    --stylua: ignore end

    return Image.alpha({
        x = 32,
        y = 32,
        mask = checkbox_mask,
    })
end

function icons.checkbox.unselected()
    --stylua: ignore start
    local checkbox_mask = {
        o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,
        o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,
        o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,
        o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,
        o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,
        o,o,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,o,o,
        o,o,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,o,o,
        o,o,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,o,o,
        o,o,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,o,o,
        o,o,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,o,o,
        o,o,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,o,o,
        o,o,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,o,o,
        o,o,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,o,o,
        o,o,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,o,o,
        o,o,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,o,o,
        o,o,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,o,o,
        o,o,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,o,o,
        o,o,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,o,o,
        o,o,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,o,o,
        o,o,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,o,o,
        o,o,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,o,o,
        o,o,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,o,o,
        o,o,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,o,o,
        o,o,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,o,o,
        o,o,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,o,o,
        o,o,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,o,o,
        o,o,X,X,X,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,X,X,X,o,o,
        o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,
        o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,
        o,o,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,o,o,
        o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,
        o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,
    }
    --stylua: ignore end

    return Image.alpha({
        x = 32,
        y = 32,
        mask = checkbox_mask,
    })
end

function icons.checkbox.select(value)
    if value then
        return icons.checkbox.selected()
    else
        return icons.checkbox.unselected()
    end
end

return icons
