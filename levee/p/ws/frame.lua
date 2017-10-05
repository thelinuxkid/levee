local ffi = require('ffi')

local encoder = require("levee.p.ws.encoder")
local parser = require("levee.p.ws.parser")


local LEN_7_MAX = 125
local LEN_16_MAX = 0xffff

local opcodes = {
	CONTINUE=C.SP_WS_CONT,
	TEXT=C.SP_WS_TEXT,
	BINARY=C.SP_WS_BIN,
	CLOSE=C.SP_WS_CLOSE,
	PING=C.SP_WS_PING,
	PONG=C.SP_WS_PONG,
}


local Frame_mt = {}
Frame_mt.__index = Frame_mt


function Frame_mt:__new()
	return ffi.new(self)
end


local mt = ffi.metatype("SpWsFrame", Frame_mt)


local function decode(parser, stream)
	local err, value = parser:stream_next(stream)
	if err then return err end
	local f = {fin=value[1], opcode=value[2], masked=value[3], n=value[4]}

	if parser:is_done() then return nil, f end

	if not f.n then
		local err, value = parser:stream_next(stream)
		if err then return err end
		f.n = value[1]
	end

	if f.masked then
		local err, value = parser:stream_next(stream)
		if err then return err end
		f.key = value[1]
	end

	f.s = ''
	while not parser:is_done() do
		local err, value = parser:stream_next(stream)
		if err then return err end
		f.s = f.s..value[1]
	end

	return nil, f
end


local function encode(buf, fin, opcode, n, key)
	local f = mt()

	f.fin = fin
	-- TODO support extensions here (RSV1, RSV2, RSV3)
	f.opcode = opcodes[opcode]

	if n then
		f.masked = key and true or false

		if n > LEN_16_MAX then
				f.paylen.type = C.SP_WS_LEN_64
				f.paylen.len.u64 = n
		elseif n > LEN_7_MAX then
				f.paylen.type = C.SP_WS_LEN_16
				f.paylen.len.u16 = n
		elseif n > 0 then
				f.paylen.type = C.SP_WS_LEN_7
				f.paylen.len.u7 = n
		else
				f.paylen.type = C.SP_WS_LEN_NONE
		end

		if key then
			-- TODO can this be done more efficiently?
			local k = ffi.new("uint8_t [4]")
			C.memcpy(k, key, 4)
			f.mask_key = k
		end
	end

	local err, rc = encoder.encode_frame(buf.buf, f)
	if err then return err end
	buf:bump(rc)

	return nil, tonumber(rc)
end

return {
	encode=encode,
	decode=decode,
}
