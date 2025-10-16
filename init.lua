local Output = require("pinnacle.output")

local state = {
    outputs = {},
}

---@class glacier.Glacier
local glacier = {
    signal = require("glacier.signal"),
    widget = require("glacier.widget"),
    bar = require("glacier.bar"),
    utils = require("glacier.utils"),
}

function glacier.output(output)
    ---@diagnostic disable-next-line: redefined-local
    local output = output or Output.get_focused()

    state.outputs[output.name] = state.outputs[output.name] or {}

    return state.outputs[output.name]
end

return glacier
