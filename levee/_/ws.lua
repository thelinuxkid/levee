local ffi = require('ffi')
local C = ffi.C


local errors = require("levee.errors")


local function mask(key, buf, len)
	if not len then
		if type(buf) == "cdata" then
			len = ffi.sizeof(buf)
		else
			len = #buf
		end
	end

	local dst = ffi.new("uint8_t [?]", len)
	C.sp_ws_mask(dst, buf, len, key)

	return ffi.string(dst, len);
end


local function encode_ping(buf, key, len)
	len = len or 0
	local rc = C.sp_ws_enc_ping (buf, len, key);
	if rc < 0 then return errors.get(rc) end

	return nil, rc
end


local function encode_pong(buf, key, len)
	len = len or 0
	local rc = C.sp_ws_enc_pong (buf, len, key);
	if rc < 0 then return errors.get(rc) end

	return nil, rc
end


return {
	mask = mask,
	encode_ping = encode_ping,
	encode_pong = encode_pong,
}
