local levee = require("levee")
local ws = require("levee.p.ws")

return {
	test_encode_0_len = function()
		local buf = levee.d.Buffer()
		local err = ws.encode(buf, true, false, 0)

		assert(not err)
		assert.equal(buf.len, 2)

		-- first byte: 10000010
		local c = buf:take(1)
		assert.equal(string.byte(c), 130)

		-- second byte: 00000000
		c = buf:take(1)
		assert.equal(string.byte(c), 0)
	end,

	test_encode_8bit_len = function()
		local buf = levee.d.Buffer()
		local err = ws.encode(buf, true, false, 11)

		assert(not err)
		assert.equal(buf.len, 2)

		-- first byte: 10000010
		local c = buf:take(1)
		assert.equal(string.byte(c), 130)

		-- second byte: 00001011
		c = buf:take(1)
		assert.equal(string.byte(c), 11)
	end,

	test_encode_8bit_len_max = function()
		local buf = levee.d.Buffer()
		local err = ws.encode(buf, true, false, 125)

		assert(not err)
		assert.equal(buf.len, 2)

		-- first byte: 10000010
		local c = buf:take(1)
		assert.equal(string.byte(c), 130)

		-- second byte: 01111101
		c = buf:take(1)
		assert.equal(string.byte(c), 125)
	end,

	test_encode_16bit_len = function()
		local buf = levee.d.Buffer()
		local err = ws.encode(buf, true, false, 0xfff)

		assert(not err)
		assert.equal(buf.len, 4)

		-- first byte: 10000010
		local c = buf:take(1)
		assert.equal(string.byte(c), 130)

		-- second byte: 01111111
		c = buf:take(1)
		assert.equal(string.byte(c), 126)

		-- third byte: 00001111, the first part of the string len
		c = buf:take(1)
		assert.equal(string.byte(c), 15)

		-- fourth byte: 11111111, the second part of the string len
		c = buf:take(1)
		assert.equal(string.byte(c), 255)
	end,

	test_encode_16bit_len_min = function()
		local buf = levee.d.Buffer()
		local err = ws.encode(buf, true, false, 126)

		assert(not err)
		assert.equal(buf.len, 4)

		-- first byte: 10000010
		local c = buf:take(1)
		assert.equal(string.byte(c), 130)

		-- second byte: 01111110
		c = buf:take(1)
		assert.equal(string.byte(c), 126)

		-- third byte: 00000000, the first part of the string len
		c = buf:take(1)
		assert.equal(string.byte(c), 0)

		-- fourth byte: 01111110, the second part of the string len
		c = buf:take(1)
		assert.equal(string.byte(c), 126)
	end,

	test_encode_16bit_len_max = function()
		local buf = levee.d.Buffer()
		local err = ws.encode(buf, true, false, 0xffff)

		assert(not err)
		assert.equal(buf.len, 4)

		-- first byte: 10000010
		local c = buf:take(1)
		assert.equal(string.byte(c), 130)

		-- second byte: 01111110
		c = buf:take(1)
		assert.equal(string.byte(c), 126)

		-- third byte: 11111111, the first part of the string len
		c = buf:take(1)
		assert.equal(string.byte(c), 255)

		-- fourth byte: 11111111, the second part of the string len
		c = buf:take(1)
		assert.equal(string.byte(c), 255)
	end,

	test_encode_64bit_len = function()
		local buf = levee.d.Buffer()
		local err = ws.encode(buf, true, false, 0xffffff)

		assert(not err)
		assert.equal(buf.len, 10)

		-- first byte: 10000010
		local c = buf:take(1)
		assert.equal(string.byte(c), 130)

		-- second byte: 01111110
		c = buf:take(1)
		assert.equal(string.byte(c), 127)

		-- third byte: 00000000, the first part of the string len
		c = buf:take(1)
		assert.equal(string.byte(c), 0)

		-- fourth byte: 00000000, the second part of the string len
		c = buf:take(1)
		assert.equal(string.byte(c), 0)

		c = buf:take(1)
		assert.equal(string.byte(c), 0)

		c = buf:take(1)
		assert.equal(string.byte(c), 0)

		c = buf:take(1)
		assert.equal(string.byte(c), 0)

		c = buf:take(1)
		assert.equal(string.byte(c), 255)

		c = buf:take(1)
		assert.equal(string.byte(c), 255)

		c = buf:take(1)
		assert.equal(string.byte(c), 255)
	end,

	test_encode_64bit_len_min = function()
		local buf = levee.d.Buffer()
		local err = ws.encode(buf, true, false, 0xffff+1)

		assert(not err)
		assert.equal(buf.len, 10)

		local c = buf:take(1)
		assert.equal(string.byte(c), 130)
		c = buf:take(1)
		assert.equal(string.byte(c), 127)
		c = buf:take(5)
		assert.equal(string.byte(c), 0)
		c = buf:take(1)
		assert.equal(string.byte(c), 1)
		c = buf:take(2)
		assert.equal(string.byte(c), 0)
	end,

	test_encode_64bit_len_max = function()
		-- the max safe range for the BitOp LuaJIT extension is +-2^51
		local buf = levee.d.Buffer()
		local err = ws.encode(buf, true, false, 0x7ffffffffffff)

		assert(not err)
		assert.equal(buf.len, 10)

		local c = buf:take(1)
		assert.equal(string.byte(c), 130)
		c = buf:take(1)
		assert.equal(string.byte(c), 127)
		c = buf:take(1)
		assert.equal(string.byte(c), 0)
		c = buf:take(1)
		assert.equal(string.byte(c), 7)
		c = buf:take(1)
		assert.equal(string.byte(c), 255)
		c = buf:take(1)
		assert.equal(string.byte(c), 255)
		c = buf:take(1)
		assert.equal(string.byte(c), 255)
		c = buf:take(1)
		assert.equal(string.byte(c), 255)
		c = buf:take(1)
		assert.equal(string.byte(c), 255)
		c = buf:take(1)
		assert.equal(string.byte(c), 255)
	end,

	test_server_key = function()
		local key = ws.server_key("dGhlIHNhbXBsZSBub25jZQ==")
		assert.equal(key, "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=")
	end,
}
