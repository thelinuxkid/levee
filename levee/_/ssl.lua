local ffi = require("ffi")
local C = ffi.load("tls")

ffi.cdef([[
static const int SHA_DIGEST_LENGTH = 20;

unsigned char *SHA1(const unsigned char *d, unsigned long n, unsigned char *md);
]])


local function sha1(buf, len)
	if not len then
		if type(buf) == "cdata" then
			len = ffi.sizeof(buf)
		else
			len = #buf
		end
	end
	local md = ffi.new("char[?]", C.SHA_DIGEST_LENGTH)
	C.SHA1(buf, len, md)

	return ffi.string(md, C.SHA_DIGEST_LENGTH)
end

return {
	sha1 = sha1,
}
