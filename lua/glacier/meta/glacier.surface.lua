---@class glacier.Surface
local Surface = {}

---@class glacier.surface.SurfaceHandle
local SurfaceHandle = {}

---Convert the SurfaceHandle into a Popup's ParentHandle.
---@return snowcap.popup.ParentHandle
function SurfaceHandle:as_parent() end ---@diagnostic disable-line:missing-return

---Return the surface's handle as a ParentHandle.
---@return glacier.surface.SurfaceHandle
function Surface:get_handle() end ---@diagnostic disable-line:missing-return

---Send a message to this surface
---@param msg any
function Surface:send_message(msg) end ---@diagnostic disable-line:unused-local
