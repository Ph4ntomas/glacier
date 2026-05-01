---@class glacier.fixup.http
local http = {}

---@class stream_methods
local stream_methods = {}

---@diagnostic disable

---Patched write_data_frame function that avoid the potential race condition from base lua-http
function stream_methods:write_data_frame(payload, end_stream, paddded, timeout, flush)
    local bor = require("http.bit").bor
    local frame_types = require("http.h2_stream").frame_types

	if self.id == 0 then
		h2_errors.PROTOCOL_ERROR("'DATA' frames MUST be associated with a stream")
	end
	if self.state ~= "open" and self.state ~= "half closed (remote)" then
		h2_errors.STREAM_CLOSED("'DATA' frame not allowed in '" .. self.state .. "' state")
	end
	local pad_len, padding = "", ""
	local flags = 0
	if end_stream then
		flags = bor(flags, 0x1)
	end
	if padded then
		flags = bor(flags, 0x8)
		pad_len = spack("> B", padded)
		padding = ("\0"):rep(padded)
	end
	payload = pad_len .. payload .. padding
	-- The entire DATA frame payload is included in flow control,
	-- including Pad Length and Padding fields if present
	if self.peer_flow_credits < #payload or self.connection.peer_flow_credits < #payload then
		h2_errors.FLOW_CONTROL_ERROR("not enough flow credits")
	end
	-- Note, write_http2_frame may yield. We apply the change now to avoid a data-race.
	self.peer_flow_credits = self.peer_flow_credits - #payload
	self.connection.peer_flow_credits = self.connection.peer_flow_credits - #payload
	local ok, err, errno = self:write_http2_frame(frame_types.DATA, flags, payload, timeout, flush)
	if not ok then return nil, err, errno end
	self.stats_sent = self.stats_sent + #payload
	if end_stream then
		if self.state == "half closed (remote)" then
			self:set_state("closed")
		else
			self:set_state("half closed (local)")
		end
	end
	return ok
end
---@diagnostic enable

function http.fixup_stream_flow_control()
    local stream = require("http.h2_stream")

    print("INFO Overwrite straam:write_data_frame")
    stream.methods.write_data_frame = stream_methods.write_data_frame
end

return http
