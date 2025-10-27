local Widget = require("snowcap.widget")
local Color = require("glacier.misc.color")

---Miscellaneous module to work with `snowcap.widget.Image`
---@class glacier.image
local image = {}

---@class glacier.image.AlphaMask
---@field x integer Width of the mask, in pixel.
---@field y integer Height of the mask, in pixel.
---@field color? snowcap.widget.Color|string Default color to use when converting the mask to an image.
---@field mask integer[] Mask definition.
local AlphaMask = {}

---Initialize a new `glacier.image.AlphaMask`
---
---@param mask glacier.image.AlphaMask
---@return glacier.image.AlphaMask
function AlphaMask:new(mask)
    mask = mask or {
        x = 0,
        y = 0,
        mask = {},
    }

    if type(mask.color) == "string" then
        mask.color = Color.from_hex(mask.color --[[@as string]])
    end

    assert(#mask.mask == mask.x * mask.y, "Invalid mask dimension")

    setmetatable(mask, self)
    self.__index = self

    return mask
end

local function _clamp(n)
    if n < 0 then
        return 0
    elseif n > 255 then
        return 255
    else
        return n
    end
end

local function invert_mask(mask)
    local ret = {}
    for _, v in ipairs(mask) do
        table.insert(ret, 255 - _clamp(v))
    end

    return ret
end

---Create a new `AlphaMask`, from by inverting the mask.
---@return glacier.image.AlphaMask
function AlphaMask:invert()
    local inverted = {
        x = self.x,
        y = self.y,
        mask = invert_mask(self.mask),
    }

    return self:new(inverted)
end

---Set the default color for this `AlphaMask`
---@param color snowcap.widget.Color|string
function AlphaMask:set_color(color)
    if type(color) == "string" then
        color = Color.from_hex(color --[[@as string]])
    end

    self.color = color
end

---Convert this AlphaMask to a `snowcap.widget.image.Handle`
---@return snowcap.widget.image.Handle
function AlphaMask:to_image_handle(color)
    color = color or self.color

    if type(color) == "string" then
        color = Color.from_hex(color --[[@as string]])
    end

    local img_data = {}

    for _, mask in ipairs(self.mask) do
        local pixel = {}

        pixel[1] = math.floor(color.red * 255)
        pixel[2] = math.floor(color.green * 255)
        pixel[3] = math.floor(color.blue * 255)
        pixel[4] = math.floor(color.alpha * _clamp(mask))

        table.insert(img_data, string.char(table.unpack(pixel)))
    end

    return {
        rgba = {
            width = self.x,
            height = self.y,
            rgba = table.concat(img_data),
        },
    }
end

---Convert this AlphaMask to a `snowcap.widget.Image`
---
---@param color? snowcap.widget.Color|string
---@return snowcap.widget.WidgetDef
function AlphaMask:to_image(color)
    return Widget.Image({
        handle = self:to_image_handle(color),
    })
end

image.AlphaMask = AlphaMask

---Create a `glacier.image.AlphaMask`.
---
---This is a shorthand for `glacier.image.AlphaMask:new(...)`
---@param ... glacier.image.AlphaMask
---@return glacier.image.AlphaMask
function image.alpha(...)
    return AlphaMask:new(...)
end

return image --[[@as glacier.image]]
