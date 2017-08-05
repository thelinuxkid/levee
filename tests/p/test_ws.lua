local levee = require("levee")
local ws = require("levee.p.ws")

return {
	test_encode = function()
		local buf = levee.d.Buffer(4096)
		local err = ws.server_encode(buf)

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
		local buf = levee.d.Buffer(4096)
		local s = "Hello World"
		local err = ws.server_encode(buf, s, s:len())

		assert(not err)
		assert.equal(buf.len, 13)

		-- first byte: 10000010
		local c = buf:take(1)
		assert.equal(string.byte(c), 130)

		-- second byte: 00001011
		c = buf:take(1)
		assert.equal(string.byte(c), 11)

		assert.equal(buf:take(11), "Hello World")
	end,

	test_encode_8bit_len_max = function()
		local buf = levee.d.Buffer(4096)
		local s = string.rep("s", 125)
		local err = ws.server_encode(buf, s, s:len())

		assert(not err)
		assert.equal(buf.len, 127)

		-- first byte: 10000010
		local c = buf:take(1)
		assert.equal(string.byte(c), 130)

		-- second byte: 01111101
		c = buf:take(1)
		assert.equal(string.byte(c), 125)

		assert.equal(buf:take(125), s)
	end,

	test_encode_16bit_len = function()
		local buf = levee.d.Buffer(0xfff*2)
		local s = string.rep("s", 0xfff)
		local err = ws.server_encode(buf, s, s:len())

		assert(not err)
		assert.equal(buf.len, 0xfff+4)

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

		assert.equal(buf:take(0xfff), s)
	end,

	test_encode_16bit_len_min = function()
		local buf = levee.d.Buffer(4096)
		local s = string.rep("s", 126)
		local err = ws.server_encode(buf, s, s:len())

		assert(not err)
		assert.equal(buf.len, 130)

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

		assert.equal(buf:take(126), s)
	end,

	test_encode_16bit_len_max = function()
		local buf = levee.d.Buffer(0xffff*2)
		local s = string.rep("s", 0xffff)
		local err = ws.server_encode(buf, s, s:len())

		assert(not err)
		assert.equal(buf.len, 0xffff+4)

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

		assert.equal(buf:take(0xffff), s)
	end,

	test_server_key = function()
		local key = ws.server_key("dGhlIHNhbXBsZSBub25jZQ==")
		assert.equal(key, "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=")
	end,
}
