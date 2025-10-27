local Output = require("pinnacle.output")

local state = {
    outputs = {},
}

---Glacier global module.
---@class glacier.Glacier
local glacier = {
    signal = require("glacier.signal"),
    widget = require("glacier.widget"),
    bar = require("glacier.bar"),
    utils = require("glacier.utils"),
    timer = require("glacier.utils.timer"),
    color = require("glacier.misc.color"),
    separators = require("glacier.misc.separators"),
}

---Return per-output storage
---
---@param output pinnacle.output.OutputHandle? If nil or absent, focused output is used instead.
---If that's nil as well, the data is stored in a special `nil` table, which can be accessed by
---passing an handle with an name set to `nil`.
---
---@return table # Per output storage table
function glacier.output(output)
    output = output or Output.get_focused()

    local key = "nil"

    if output and output.name then
        key = output.name
    end

    state.outputs[key] = state.outputs[key] or {}

    return state.outputs[key]
end

return glacier --[[@as glacier.Glacier]]
