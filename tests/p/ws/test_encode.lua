local ffi = require('ffi')

local Buffer = require("levee.d.buffer")
local encoder = require("levee.p.ws.encoder")


return {
	test_mask = function()
		local key = ffi.new("uint8_t [?]", 4, 0x55, 0x7f, 0x90, 0x4a)
		local buf = ffi.new("uint8_t [?]", 11, "Hello World")

 	local cmp = ffi.new("uint8_t [?]", 11, 0x1d, 0x1a, 0xfc, 0x26, 0x3a,
			0x5f, 0xc7, 0x25, 0x27, 0x13, 0xf4)
		cmp = ffi.string(cmp, 11)

		assert.equal(encoder.mask(key, buf), cmp)
	end,

	test_encode_ping = function()
		local buf = Buffer(4096)
		local err, rc = encoder.encode_ping(buf.buf)

		assert(not err)
		assert.equal(rc, 2)
		buf:bump(rc)

		local c = buf:take(1)
		assert.equal(string.byte(c), 0x89)
		c = buf:take(1)
		assert.equal(string.byte(c), 0)
	end,

	test_encode_pong = function()
		local buf = Buffer(4096)
		local err, rc = encoder.encode_pong(buf.buf)

		assert(not err)
		assert.equal(rc, 2)
		buf:bump(rc)

		local c = buf:take(1)
		assert.equal(string.byte(c), 0x8a)
		c = buf:take(1)
		assert.equal(string.byte(c), 0)
	end,

	test_encode_close = function()
		local buf = Buffer(4096)
		local err, rc = encoder.encode_close(buf.buf, C.SP_WS_STATUS_AWAY)

		assert(not err)
		assert.equal(rc, 6)
		buf:bump(rc)

		local c = buf:take(1)
		assert.equal(string.byte(c), 0x88)
		c = buf:take(1)
		assert.equal(string.byte(c), 0x04)
		c = buf:take(1)
		assert.equal(string.byte(c), 0x03)
		c = buf:take(1)
		assert.equal(string.byte(c), 0xe9)
		c = buf:take(1)
		assert.equal(string.byte(c), 0x20)
		c = buf:take(1)
		assert.equal(string.byte(c), 0x20)
	end,
}
