local levee = require("levee")
local ws = require("levee.p.ws")

return {
	test_encode_0_len = function()
		local buf = levee.d.Buffer()
		local err = ws._encode(buf, true, ws.BIN, false, 0)

		assert(not err)
		assert.equal(buf.len, 2)

		local c = buf:take(1)
		assert.equal(string.byte(c), 130)
		c = buf:take(1)
		assert.equal(string.byte(c), 0)
	end,

	test_encode_8bit_len = function()
		local buf = levee.d.Buffer()
		local err = ws._encode(buf, true, ws.BIN, false, 11)

		assert(not err)
		assert.equal(buf.len, 2)

		local c = buf:take(1)
		assert.equal(string.byte(c), 130)
		c = buf:take(1)
		assert.equal(string.byte(c), 11)
	end,

	test_encode_8bit_len_max = function()
		local buf = levee.d.Buffer()
		local err = ws._encode(buf, true, ws.BIN, false, 125)

		assert(not err)
		assert.equal(buf.len, 2)

		local c = buf:take(1)
		assert.equal(string.byte(c), 130)
		c = buf:take(1)
		assert.equal(string.byte(c), 125)
	end,

	test_encode_16bit_len = function()
		local buf = levee.d.Buffer()
		local err = ws._encode(buf, true, ws.BIN, false, 0xfff)

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
		local err = ws._encode(buf, true, ws.BIN, false, 126)

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
		local err = ws._encode(buf, true, ws.BIN, false, 0xffff)

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
		local err = ws._encode(buf, true, ws.BIN, false, 0xffffff)

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
		local err = ws._encode(buf, true, ws.BIN, false, 0xffff+1)

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
		local err = ws._encode(buf, true, ws.BIN, false, 0x7ffffffffffff)

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
		local err = ws._encode(buf, true, ws.BIN, false, 0xffff+1)

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
		local err = ws._encode(buf, true, ws.BIN, false, 0x7ffffffffffff)

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
		local err = ws._encode(buf, true, ws.BIN, false, -1)

		assert(err.is_ws_MINLEN)
	end,

	test_encode_max_len = function()
		local buf = levee.d.Buffer()
		local err = ws._encode(buf, true, ws.BIN, false, 0x7ffffffffffff+1)

		assert(err.is_ws_MAXLEN)
	end,

	test_encode_fin = function()
		-- FIN set
		local buf = levee.d.Buffer()
		local err = ws._encode(buf, true, ws.BIN, false, 0)

		assert(not err)
		assert.equal(buf.len, 2)

		local c = buf:take(1)
		assert.equal(string.byte(c), 130)
		c = buf:take(1)
		assert.equal(string.byte(c), 0)

		-- FIN not set
		buf = levee.d.Buffer()
		err = ws._encode(buf, false, ws.BIN, false, 0)

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
		local err = ws._encode(buf, false, ws.BIN, true, 0)

		assert(not err)
		assert.equal(buf.len, 2)

		local c = buf:take(1)
		assert.equal(string.byte(c), 2)
		c = buf:take(1)
		assert.equal(string.byte(c), 128)

		-- mask not set
		buf = levee.d.Buffer()
		err = ws._encode(buf, false, ws.BIN, false, 0)

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
		err = ws._encode(buf, false, ws.CONT, false, 0)

		assert(not err)
		assert.equal(buf.len, 2)

		c = buf:take(1)
		assert.equal(string.byte(c), 0)
		c = buf:take(1)
		assert.equal(string.byte(c), 0)

		-- text opcode
		buf = levee.d.Buffer()
		err = ws._encode(buf, false, ws.TEXT, false, 0)

		assert(not err)
		assert.equal(buf.len, 2)

		c = buf:take(1)
		assert.equal(string.byte(c), 1)
		c = buf:take(1)
		assert.equal(string.byte(c), 0)

		-- bin opcode
		local buf = levee.d.Buffer()
		local err = ws._encode(buf, false, ws.BIN, false, 0)

		assert(not err)
		assert.equal(buf.len, 2)

		local c = buf:take(1)
		assert.equal(string.byte(c), 2)
		c = buf:take(1)
		assert.equal(string.byte(c), 0)

		-- close opcode
		local buf = levee.d.Buffer()
		local err = ws._encode(buf, false, ws.CLOSE, false, 0)

		assert(not err)
		assert.equal(buf.len, 2)

		local c = buf:take(1)
		assert.equal(string.byte(c), 8)
		c = buf:take(1)
		assert.equal(string.byte(c), 0)

		-- ping opcode
		local buf = levee.d.Buffer()
		local err = ws._encode(buf, false, ws.PING, false, 0)

		assert(not err)
		assert.equal(buf.len, 2)

		local c = buf:take(1)
		assert.equal(string.byte(c), 9)
		c = buf:take(1)
		assert.equal(string.byte(c), 0)

		-- pong opcode
		local buf = levee.d.Buffer()
		local err = ws._encode(buf, false, ws.PONG, false, 0)

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

	test_server_frame = function()
		local buf = levee.d.Buffer()
		local err = ws.server_frame(buf, "Hello World")

		assert(not err)
		assert.equal(buf.len, 13)

		local c = buf:take(1)
		assert.equal(string.byte(c), 2)
		c = buf:take(1)
		assert.equal(string.byte(c), 11)
		assert.equal(buf:take(11), "Hello World")
	end,

	test_server_frame_next = function()
		local buf = levee.d.Buffer()
		local err = ws.server_frame_next(buf, "Hello World")

		assert(not err)
		assert.equal(buf.len, 13)

		local c = buf:take(1)
		assert.equal(string.byte(c), 0)
		c = buf:take(1)
		assert.equal(string.byte(c), 11)
		assert.equal(buf:take(11), "Hello World")
	end,

	test_server_frame_last = function()
		local buf = levee.d.Buffer()
		local err = ws.server_frame_last(buf, "Hello World")

		assert(not err)
		assert.equal(buf.len, 13)

		local c = buf:take(1)
		assert.equal(string.byte(c), 128)
		c = buf:take(1)
		assert.equal(string.byte(c), 11)
		assert.equal(buf:take(11), "Hello World")
	end,

	test_server_key = function()
		local key = ws._server_key("dGhlIHNhbXBsZSBub25jZQ==")
		assert.equal(key, "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=")
	end,

	test_mask_payload = function()
		local key = 1434423370
		local data = "Hello World"
		local data = ws._mask_payload(data, data:len(), key)
		local buf = levee.d.Buffer()
		buf:push(data)

		local c = buf:take(1)
		assert.equal(string.byte(c), 29)
		c = buf:take(1)
		assert.equal(string.byte(c), 26)
		c = buf:take(1)
		assert.equal(string.byte(c), 252)
		c = buf:take(1)
		assert.equal(string.byte(c), 38)
		c = buf:take(1)
		assert.equal(string.byte(c), 58)
		c = buf:take(1)
		assert.equal(string.byte(c), 95)
		c = buf:take(1)
		assert.equal(string.byte(c), 199)
		c = buf:take(1)
		assert.equal(string.byte(c), 37)
		c = buf:take(1)
		assert.equal(string.byte(c), 39)
		c = buf:take(1)
		assert.equal(string.byte(c), 19)
		c = buf:take(1)
		assert.equal(string.byte(c), 244)
	end,

	test_masking_key = function()
		local k = string.char(212)
		k = k..string.char(135)
		k = k..string.char(17)
		k = k..string.char(136)

		assert.equal(ws._masking_key(k), -729345656)
	end,

	test_client_encode = function()
		local buf = levee.d.Buffer()
		local err = ws.client_encode(buf, "Hello World")

		assert(not err)
		assert.equal(buf.len, 17)

		local c = buf:take(1)
		assert.equal(string.byte(c), 130)
		c = buf:take(1)
		assert.equal(string.byte(c), 139)
		local k = buf:take(4)
		k = ws._masking_key(k)
		c = buf:take(11)
		assert.equal(ws._unmask_payload(c, 11, k), "Hello World")
	end,

	test_client_frame = function()
		local buf = levee.d.Buffer()
		local err = ws.client_frame(buf, "Hello World")

		assert(not err)
		assert.equal(buf.len, 17)

		local c = buf:take(1)
		assert.equal(string.byte(c), 2)
		c = buf:take(1)
		assert.equal(string.byte(c), 139)
		local k = buf:take(4)
		k = ws._masking_key(k)
		c = buf:take(11)
		assert.equal(ws._unmask_payload(c, 11, k), "Hello World")
	end,

	test_client_frame_next = function()
		local buf = levee.d.Buffer()
		local err = ws.client_frame_next(buf, "Hello World")

		assert(not err)
		assert.equal(buf.len, 17)

		local c = buf:take(1)
		assert.equal(string.byte(c), 0)
		c = buf:take(1)
		assert.equal(string.byte(c), 139)
		local k = buf:take(4)
		k = ws._masking_key(k)
		c = buf:take(11)
		assert.equal(ws._unmask_payload(c, 11, k), "Hello World")
	end,

	test_client_frame_last = function()
		local buf = levee.d.Buffer()
		local err = ws.client_frame_last(buf, "Hello World")

		assert(not err)
		assert.equal(buf.len, 17)

		local c = buf:take(1)
		assert.equal(string.byte(c), 128)
		c = buf:take(1)
		assert.equal(string.byte(c), 139)
		local k = buf:take(4)
		k = ws._masking_key(k)
		c = buf:take(11)
		assert.equal(ws._unmask_payload(c, 11, k), "Hello World")
	end,

	test_ping = function()
		local buf = levee.d.Buffer()
		local err = ws.ping(buf)

		assert(not err)
		assert.equal(buf.len, 2)

		local c = buf:take(1)
		assert.equal(string.byte(c), 137)
		c = buf:take(1)
		assert.equal(string.byte(c), 0)
	end,

	test_ping_body = function()
		local buf = levee.d.Buffer()
		local err = ws.ping(buf, "Hello World")

		assert(not err)
		assert.equal(buf.len, 13)

		local c = buf:take(1)
		assert.equal(string.byte(c), 137)
		c = buf:take(1)
		assert.equal(string.byte(c), 11)
	end,

	test_pong = function()
		local buf = levee.d.Buffer()
		local err = ws.pong(buf)

		assert(not err)
		assert.equal(buf.len, 2)

		local c = buf:take(1)
		assert.equal(string.byte(c), 138)
		c = buf:take(1)
		assert.equal(string.byte(c), 0)
	end,

	test_pong_body = function()
		local buf = levee.d.Buffer()
		local err = ws.pong(buf, "Hello World")

		assert(not err)
		assert.equal(buf.len, 13)

		local c = buf:take(1)
		assert.equal(string.byte(c), 138)
		c = buf:take(1)
		assert.equal(string.byte(c), 11)
	end,

	test_ctrl_max_len = function()
		local buf = levee.d.Buffer()
		local s = string.rep("s", 126)
		local err = ws._ctrl(buf, s, PONG)

		assert(err.is_ws_MAXCTRL)
	end,
}
