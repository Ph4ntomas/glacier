---@module 'cqueues'

---@type cqueues
local cqueues = require("cqueues")

---@class glacier.internal.event_loop
---@field loop cqueues.cqueue Glacier's event_loop
local event_loop = {}

local mt = {}

function mt:__index(property)
    if property == "loop" then
        local loop = rawget(self, property)
        -- Return the stored loop
        if loop ~= nil then
            return loop
        else
            local main_loop = cqueues.running()

            if main_loop == nil then
                error("cqueue.loop was accessed before pinnacle initialization.")
            else
                rawset(self, property, main_loop)
                return main_loop
            end
        end
    end

    return event_loop[property]
end

return setmetatable(event_loop, mt)
