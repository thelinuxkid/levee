local ffi = require('ffi')
local C = ffi.C


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

return {
	mask = mask,
}
