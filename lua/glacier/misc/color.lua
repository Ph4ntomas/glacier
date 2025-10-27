local Widget = require("snowcap.widget")

---Color utility module.
---
---@class glacier.color
local color = {}

---Check that a given number is inside a range
---@param n number Number to check.
---@param low number Lower bound.
---@param high number Upper bound.
---@return boolean
local function _check_range(n, low, high)
    return n >= low and n <= high
end

---Create a `snowcap.widget.Color`, with bound checking.
---
---@param r number Red component.
---@param g number Green component.
---@param b number Blue component.
---@param a? number Alpha (transparency) value.
---@return snowcap.widget.Color
function color.from_rgba(r, g, b, a)
    local range = function(n)
        return _check_range(n, 0.0, 1.0)
    end

    assert(range(r), "Invalid range for red. Expected 0.0 <= r <= 1.0, got: " .. tostring(r))
    assert(range(g), "Invalid range for green. Expected 0.0 <= g <= 1.0, got: " .. tostring(g))
    assert(range(b), "Invalid range for blue. Expected 0.0 <= b <= 1.0, got: " .. tostring(b))

    if a then
        assert(range(a), "Invalid range for alpha. Expected 0.0 <= r <= 1.0, got: " .. tostring(a))
    end

    return Widget.color.from_rgba(r, g, b, a)
end

---Create a `snowcap.widget.Color`, from integer, with bound checking.
---
---This function acts as color.from_rgba, except the values are expected to be integer in the range
---0..=255, and will be divided by 255 before being passed to snowcap.widget.color.from_rgba.
---
---@param r number Red component.
---@param g number Green component.
---@param b number Blue component.
---@param a? number Alpha (transparency) value.
---@return snowcap.widget.Color
function color.from_int_rgba(r, g, b, a)
    ---@diagnostic disable-next-line: redefined-local
    local range = function(n)
        return _check_range(n, 0, 255)
    end

    assert(range(r), "Invalid range for red. Expected 0 <= r <= 255, got: " .. tostring(r))
    assert(range(g), "Invalid range for green. Expected 0 <= g <= 255, got: " .. tostring(g))
    assert(range(b), "Invalid range for blue. Expected 0 <= b <= 255, got: " .. tostring(b))

    if a then
        assert(range(a), "Invalid range for alpha. Expected 0 <= r <= 255, got: " .. tostring(a))
    end

    return Widget.color.from_rgba(r / 255.0, g / 255.0, b / 255.0, a and a / 255.0 or nil)
end

---Convert an hexadecimal color code to a `snowcap.widet.color`.
---
---@param hex_color string An hex encoded color, in the form #RRGGBB or #RGB.
---@param alpha? number An optional Alpha, between 0.0 and 1.0.
---@return snowcap.widget.Color
function color.from_hex(hex_color, alpha)
    local ret = {}

    local matches = { string.match(string.lower(hex_color), "^#(%x%x)(%x%x)(%x%x)$") }

    if matches == nil then
        matches = { string.match(string.lower(hex_color), "^#(%x)(%x)(%x)$") }
        if matches then
            for k, v in ipairs(matches) do
                matches[k] = v .. v
            end
        end
    end

    if not matches then
        error("Invalid pattern. Expexted '#RRGGBB' or '#RGB', got: " .. hex_color)
    end

    for _, match in ipairs(matches) do
        table.insert(ret, tonumber(match, 16) / 255.0)
    end

    if alpha then
        assert(
            _check_range(alpha, 0.0, 1.0),
            "Invalid range for alpha. Expected 0.0 <= r <= 1.0, got: " .. tostring(alpha)
        )
    end

    table.insert(ret, alpha)

    return Widget.color.from_rgba(table.unpack(ret))
end

return color --[[@as glacier.color]]
