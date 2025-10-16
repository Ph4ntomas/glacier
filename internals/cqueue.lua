---@class glacier.internal.cqueue
---@field loop cqueues.cqueue
local cqueue = {}

local mt = {}

function mt:__index(property)
    if property == "loop" then
        local loop = rawget(self, property)
        -- Return the stored loop
        if loop ~= nil then
            return loop
        else
            --Yoink pinnacle loop if available. This stunt was done by professionals,
            --don't repeat it at home.
            local main_loop = require("pinnacle.grpc.client").client.loop

            if main_loop == nil then
                error("cqueue.loop was accessed before pinnacle initialization.")
            else
                rawset(self, property, main_loop)
                return main_loop
            end
        end
    end

    return cqueue[property]
end

return setmetatable(cqueue, mt)
