local levee = require("levee")
local ws = require("levee.p.ws")

return {
	test_encode_0_len = function()
		local buf = levee.d.Buffer()
		local err = ws.encode(buf, true, ws.BIN, false, 0)

		assert(not err)
		assert.equal(buf.len, 2)

		local c = buf:take(1)
		assert.equal(string.byte(c), 130)
		c = buf:take(1)
		assert.equal(string.byte(c), 0)
	end,

	test_encode_8bit_len = function()
		local buf = levee.d.Buffer()
		local err = ws.encode(buf, true, ws.BIN, false, 11)

		assert(not err)
		assert.equal(buf.len, 2)

		local c = buf:take(1)
		assert.equal(string.byte(c), 130)
		c = buf:take(1)
		assert.equal(string.byte(c), 11)
	end,

	test_encode_8bit_len_max = function()
		local buf = levee.d.Buffer()
		local err = ws.encode(buf, true, ws.BIN, false, 125)

		assert(not err)
		assert.equal(buf.len, 2)

		local c = buf:take(1)
		assert.equal(string.byte(c), 130)
		c = buf:take(1)
		assert.equal(string.byte(c), 125)
	end,

	test_encode_16bit_len = function()
		local buf = levee.d.Buffer()
		local err = ws.encode(buf, true, ws.BIN, false, 0xfff)

		assert(not err)
		assert.equal(buf.len, 4)

		local c = buf:take(1)
		assert.equal(string.byte(c), 130)
		c = buf:take(1)
		assert.equal(string.byte(c), 126)
		c = buf:take(1)
		assert.equal(string.byte(c), 15)
		c = buf:take(1)
		assert.equal(string.byte(c), 255)
	end,

	test_encode_16bit_len_min = function()
		local buf = levee.d.Buffer()
		local err = ws.encode(buf, true, ws.BIN, false, 126)

		assert(not err)
		assert.equal(buf.len, 4)

		local c = buf:take(1)
		assert.equal(string.byte(c), 130)
		c = buf:take(1)
		assert.equal(string.byte(c), 126)
		c = buf:take(1)
		assert.equal(string.byte(c), 0)
		c = buf:take(1)
		assert.equal(string.byte(c), 126)
	end,

	test_encode_16bit_len_max = function()
		local buf = levee.d.Buffer()
		local err = ws.encode(buf, true, ws.BIN, false, 0xffff)

		assert(not err)
		assert.equal(buf.len, 4)

		local c = buf:take(1)
		assert.equal(string.byte(c), 130)
		c = buf:take(1)
		assert.equal(string.byte(c), 126)
		c = buf:take(1)
		assert.equal(string.byte(c), 255)
		c = buf:take(1)
		assert.equal(string.byte(c), 255)
	end,

	test_encode_64bit_len = function()
		local buf = levee.d.Buffer()
		local err = ws.encode(buf, true, ws.BIN, false, 0xffffff)

		assert(not err)
		assert.equal(buf.len, 10)

		local c = buf:take(1)
		assert.equal(string.byte(c), 130)
		c = buf:take(1)
		assert.equal(string.byte(c), 127)
		c = buf:take(5)
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
		local err = ws.encode(buf, true, ws.BIN, false, 0xffff+1)

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
		local err = ws.encode(buf, true, ws.BIN, false, 0x7ffffffffffff)

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

	test_encode_64bit_len_min = function()
		local buf = levee.d.Buffer()
		local err = ws.encode(buf, true, ws.BIN, false, 0xffff+1)

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
		local err = ws.encode(buf, true, ws.BIN, false, 0x7ffffffffffff)

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

	test_encode_min_len = function()
		local buf = levee.d.Buffer()
		local err = ws.encode(buf, true, ws.BIN, false, -1)

		assert(err.is_ws_MINLEN)
	end,

	test_encode_max_len = function()
		local buf = levee.d.Buffer()
		local err = ws.encode(buf, true, ws.BIN, false, 0x7ffffffffffff+1)

		assert(err.is_ws_MAXLEN)
	end,

	test_encode_fin = function()
		-- FIN set
		local buf = levee.d.Buffer()
		local err = ws.encode(buf, true, ws.BIN, false, 0)

		assert(not err)
		assert.equal(buf.len, 2)

		local c = buf:take(1)
		assert.equal(string.byte(c), 130)
		c = buf:take(1)
		assert.equal(string.byte(c), 0)

		-- FIN not set
		buf = levee.d.Buffer()
		err = ws.encode(buf, false, ws.BIN, false, 0)

		assert(not err)
		assert.equal(buf.len, 2)

		c = buf:take(1)
		assert.equal(string.byte(c), 2)
		c = buf:take(1)
		assert.equal(string.byte(c), 0)
	end,

	test_encode_mask = function()
		-- mask set
		local buf = levee.d.Buffer()
		local err = ws.encode(buf, false, ws.BIN, true, 0)

		assert(not err)
		assert.equal(buf.len, 2)

		local c = buf:take(1)
		assert.equal(string.byte(c), 2)
		c = buf:take(1)
		assert.equal(string.byte(c), 128)

		-- mask not set
		buf = levee.d.Buffer()
		err = ws.encode(buf, false, ws.BIN, false, 0)

		assert(not err)
		assert.equal(buf.len, 2)

		c = buf:take(1)
		assert.equal(string.byte(c), 2)
		c = buf:take(1)
		assert.equal(string.byte(c), 0)
	end,

	test_encode_opcode = function()
		-- cont opcode
		buf = levee.d.Buffer()
		err = ws.encode(buf, false, ws.CONT, false, 0)

		assert(not err)
		assert.equal(buf.len, 2)

		c = buf:take(1)
		assert.equal(string.byte(c), 0)
		c = buf:take(1)
		assert.equal(string.byte(c), 0)

		-- text opcode
		buf = levee.d.Buffer()
		err = ws.encode(buf, false, ws.TEXT, false, 0)

		assert(not err)
		assert.equal(buf.len, 2)

		c = buf:take(1)
		assert.equal(string.byte(c), 1)
		c = buf:take(1)
		assert.equal(string.byte(c), 0)

		-- bin opcode
		local buf = levee.d.Buffer()
		local err = ws.encode(buf, false, ws.BIN, false, 0)

		assert(not err)
		assert.equal(buf.len, 2)

		local c = buf:take(1)
		assert.equal(string.byte(c), 2)
		c = buf:take(1)
		assert.equal(string.byte(c), 0)

		-- close opcode
		local buf = levee.d.Buffer()
		local err = ws.encode(buf, false, ws.CLOSE, false, 0)

		assert(not err)
		assert.equal(buf.len, 2)

		local c = buf:take(1)
		assert.equal(string.byte(c), 8)
		c = buf:take(1)
		assert.equal(string.byte(c), 0)

		-- ping opcode
		local buf = levee.d.Buffer()
		local err = ws.encode(buf, false, ws.PING, false, 0)

		assert(not err)
		assert.equal(buf.len, 2)

		local c = buf:take(1)
		assert.equal(string.byte(c), 9)
		c = buf:take(1)
		assert.equal(string.byte(c), 0)

		-- pong opcode
		local buf = levee.d.Buffer()
		local err = ws.encode(buf, false, ws.PONG, false, 0)

		assert(not err)
		assert.equal(buf.len, 2)

		local c = buf:take(1)
		assert.equal(string.byte(c), 10)
		c = buf:take(1)
		assert.equal(string.byte(c), 0)
	end,

	test_server_encode = function()
		local buf = levee.d.Buffer()
		local err = ws.server_encode(buf, "Hello World")

		assert(not err)
		assert.equal(buf.len, 13)

		local c = buf:take(1)
		assert.equal(string.byte(c), 130)
		c = buf:take(1)
		assert.equal(string.byte(c), 11)
		assert.equal(buf:take(11), "Hello World")
	end,

	test_server_key = function()
		local key = ws.server_key("dGhlIHNhbXBsZSBub25jZQ==")
		assert.equal(key, "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=")
	end,
}
