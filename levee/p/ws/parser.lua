local ffi = require('ffi')
local C = ffi.C

local errors = require("levee.errors")


local opcodes = {
	[C.SP_WS_CONT]="CONTINUE",
	[C.SP_WS_TEXT]="TEXT",
	[C.SP_WS_BIN]="BINARY",
	[C.SP_WS_CLOSE]="CLOSE",
	[C.SP_WS_PING]="PING",
	[C.SP_WS_PONG]="PONG",
}


local Parser_mt = {}
Parser_mt.__index = Parser_mt


function Parser_mt:__new()
	return ffi.new(self)
end


function Parser_mt:init()
	C.sp_ws_init(self)
end


function Parser_mt:reset()
	C.sp_ws_reset(self)
end


function Parser_mt:unmask(buf, len)
	local dst = ffi.new("uint8_t [?]", len)
	local rc = C.sp_ws_unmask(self, dst, buf, len)
	if rc < 0 then errors.get(rc) end

	return ffi.string(dst, rc)
end


function Parser_mt:next(buf, len)
	local rc = C.sp_ws_next(self, buf, len)
	if rc >= 0 then
		return nil, rc
	end
	return errors.get(rc)
end


function Parser_mt:is_done()
	return C.sp_ws_is_done(self)
end


function Parser_mt:value(buf, n)
	if self.type == C.SP_WS_META then
		local n
		if (self.as.paylen.type == C.SP_WS_LEN_7) then
			n = tonumber(self.as.paylen.len.u7)
		end
		return
			self.as.fin,
			opcodes[tonumber(self.as.opcode)],
			self.as.masked,
			n
	elseif self.type == C.SP_WS_PAYLEN then
		local n = 0
		if self.as.paylen.type == C.SP_WS_LEN_64 then
			n = self.as.paylen.len.u64
		end
		if self.as.paylen.type == C.SP_WS_LEN_16 then
			n = self.as.paylen.len.u16
		end
		if self.as.paylen.type == C.SP_WS_LEN_7 then
			n = self.as.paylen.len.u7
		end
		return n > 0 and tonumber(n) or nil
	elseif self.type == C.SP_WS_MASK_KEY then
		return self.as.mask_key
	elseif self.type == C.SP_WS_PAYLOAD then
		local s = ffi.string(buf, n)
		if self.as.masked then s = self:unmask(buf, n) end
		return s
	end
end


function Parser_mt:stream_next(stream)
	local err, n = self:next(stream:value())
	if err then return err end

	if n > 0 then
		local value = {self:value(stream:value(n))}
		stream:trim(n)
		if self:is_done() then
			self:reset()
		end
		return nil, value
	end

	local err, n = stream:readin()
	if err then
		if err == errors.CLOSED then
			return errors.ws.ESYNTAX
		end
		return err
	end
	return self:stream_next(stream)
end


return ffi.metatype("SpWs", Parser_mt)
