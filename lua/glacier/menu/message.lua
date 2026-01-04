---@class glacier.menu.message
local message = {}
message.TYPE_NAME = "glacier.menu.Message"

---@alias glacier.menu.Action glacier.menu.action.Entry|glacier.menu.action.Menu

---@class glacier.menu.Message
---@field action glacier.menu.Action
---@field [string] any Extra parameters
local Message = {}
Message.__index = Message
Message.__name = message.TYPE_NAME

---@param msg glacier.menu.Message
function Message.new(msg)
    return setmetatable(msg, Message)
end

message.Message = Message

function message.type(msg)
    local typename = type(msg)

    if typename == "table" then
        return getmetatable(msg) == Message and message.TYPE_NAME or typename
    end

    return typename
end

return message
