local ffi = require('ffi')

local levee = require("levee")
local _ = require("levee._")
local ws = require("levee.p.ws")


return {
	test_encode_0_len = function()
		local buf = levee.d.Buffer(4096)
		local err = ws._encode(buf, true, C.SP_WS_BIN)

		assert(not err)
		assert.equal(buf.len, 2)

		local c = buf:take(1)
		assert.equal(string.byte(c), 130)
		c = buf:take(1)
		assert.equal(string.byte(c), 0)
	end,

	test_encode_8bit_len = function()
		local buf = levee.d.Buffer(4096)
		local err = ws._encode(buf, true, C.SP_WS_BIN, 11)

		assert(not err)
		assert.equal(buf.len, 2)

		local c = buf:take(1)
		assert.equal(string.byte(c), 130)
		c = buf:take(1)
		assert.equal(string.byte(c), 11)
	end,

	test_encode_16bit_len = function()
		local buf = levee.d.Buffer(4096)
		local err = ws._encode(buf, true, C.SP_WS_BIN, 0xfff)

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

	test_encode_64bit_len = function()
		local buf = levee.d.Buffer(4096)
		local err = ws._encode(buf, true, C.SP_WS_BIN, 0xffffff)

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

	test_encode_max_len = function()
		local buf = levee.d.Buffer(4096)
		local err = ws._encode(buf, true, C.SP_WS_BIN, 0x0fffffffffffffff+1)

		assert(err.is_ws_ELENMAX)
	end,

	test_server_encode = function()
		local buf = levee.d.Buffer(4096)
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
		local buf = levee.d.Buffer(4096)
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
		local buf = levee.d.Buffer(4096)
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
		local buf = levee.d.Buffer(4096)
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

	test_client_encode = function()
		local buf = levee.d.Buffer(4096)
		local err = ws.client_encode(buf, "Hello World")

		assert(not err)
		assert.equal(buf.len, 17)

		local c = buf:take(1)
		assert.equal(string.byte(c), 130)
		c = buf:take(1)
		assert.equal(string.byte(c), 139)
		local k = buf:take(4)
		c = buf:take(11)
		assert.equal(_.ws.mask(k, c, 11), "Hello World")
	end,

	test_client_frame = function()
		local buf = levee.d.Buffer(4096)
		local err = ws.client_frame(buf, "Hello World")

		assert(not err)
		assert.equal(buf.len, 17)

		local c = buf:take(1)
		assert.equal(string.byte(c), 2)
		c = buf:take(1)
		assert.equal(string.byte(c), 139)
		local k = buf:take(4)
		c = buf:take(11)
		assert.equal(_.ws.mask(k, c, 11), "Hello World")
	end,

	test_client_frame_next = function()
		local buf = levee.d.Buffer(4096)
		local err = ws.client_frame_next(buf, "Hello World")

		assert(not err)
		assert.equal(buf.len, 17)

		local c = buf:take(1)
		assert.equal(string.byte(c), 0)
		c = buf:take(1)
		assert.equal(string.byte(c), 139)
		local k = buf:take(4)
		c = buf:take(11)
		assert.equal(_.ws.mask(k, c, 11), "Hello World")
	end,

	test_client_frame_last = function()
		local buf = levee.d.Buffer(4096)
		local err = ws.client_frame_last(buf, "Hello World")

		assert(not err)
		assert.equal(buf.len, 17)

		local c = buf:take(1)
		assert.equal(string.byte(c), 128)
		c = buf:take(1)
		assert.equal(string.byte(c), 139)
		local k = buf:take(4)
		c = buf:take(11)
		assert.equal(_.ws.mask(k, c, 11), "Hello World")
	end,

	test_client_close = function()
		local buf = levee.d.Buffer(4096)
		local err = ws.client_close(buf, C.SP_WS_STATUS_AWAY)

		assert(not err)
		assert.equal(buf.len, 20)

		local c = buf:take(1)
		assert.equal(string.byte(c), 136)
		c = buf:take(1)
		assert.equal(string.byte(c), 142)
		local k = ws._masking_key(buf:take(4))
		c = buf:take(14)
		c = _.ws.mask(k, c, 14)
		assert.equal(string.sub(c, 5, 14), "Going Away")
	end,

	test_server_close = function()
		local buf = levee.d.Buffer(4096)
		local err = ws.server_close(buf, C.SP_WS_STATUS_AWAY)

		assert(not err)
		assert.equal(buf.len, 16)

		local c = buf:take(1)
		assert.equal(string.byte(c), 136)
		c = buf:take(1)
		assert.equal(string.byte(c), 14)
		c = buf:take(14)
		assert.equal(string.sub(c, 5, 14), "Going Away")
	end,

	test_client_ping = function()
		local buf = levee.d.Buffer(4096)
		local err = ws.client_ping(buf)

		assert(not err)
		assert.equal(buf.len, 6)

		local c = buf:take(1)
		assert.equal(string.byte(c), 137)
		c = buf:take(1)
		assert.equal(string.byte(c), 128)
	end,

	test_client_ping_body = function()
		local buf = levee.d.Buffer(4096)
		local err = ws.client_ping(buf, "Hello World")

		assert(not err)
		assert.equal(buf.len, 17)

		local c = buf:take(1)
		assert.equal(string.byte(c), 137)
		local c = buf:take(1)
		assert.equal(string.byte(c), 139)
		local k = ws._masking_key(buf:take(4))
		c = buf:take(11)
		assert.equal(_.ws.mask(k, c, 11), "Hello World")
	end,

	test_server_ping = function()
		local buf = levee.d.Buffer(4096)
		local err = ws.server_ping(buf)

		assert(not err)
		assert.equal(buf.len, 2)

		local c = buf:take(1)
		assert.equal(string.byte(c), 137)
		c = buf:take(1)
		assert.equal(string.byte(c), 0)
	end,

	test_server_ping_body = function()
		local buf = levee.d.Buffer(4096)
		local err = ws.server_ping(buf, "Hello World")

		assert(not err)
		assert.equal(buf.len, 13)

		local c = buf:take(1)
		assert.equal(string.byte(c), 137)
		c = buf:take(1)
		assert.equal(string.byte(c), 11)
		assert.equal(buf:take(11), "Hello World")
	end,

	test_client_pong = function()
		local buf = levee.d.Buffer(4096)
		local err = ws.client_pong(buf)

		assert(not err)
		assert.equal(buf.len, 6)

		local c = buf:take(1)
		assert.equal(string.byte(c), 138)
		c = buf:take(1)
		assert.equal(string.byte(c), 128)
	end,

	test_client_pong_body = function()
		local buf = levee.d.Buffer(4096)
		local err = ws.client_pong(buf, "Hello World")

		assert(not err)
		assert.equal(buf.len, 17)

		local c = buf:take(1)
		assert.equal(string.byte(c), 138)
		local c = buf:take(1)
		assert.equal(string.byte(c), 139)
		local k = ws._masking_key(buf:take(4))
		c = buf:take(11)
		assert.equal(_.ws.mask(k, c, 11), "Hello World")
	end,

	test_server_pong = function()
		local buf = levee.d.Buffer(4096)
		local err = ws.server_pong(buf)

		assert(not err)
		assert.equal(buf.len, 2)

		local c = buf:take(1)
		assert.equal(string.byte(c), 138)
		c = buf:take(1)
		assert.equal(string.byte(c), 0)
	end,

	test_server_pong_body = function()
		local buf = levee.d.Buffer(4096)
		local err = ws.server_pong(buf, "Hello World")

		assert(not err)
		assert.equal(buf.len, 13)

		local c = buf:take(1)
		assert.equal(string.byte(c), 138)
		c = buf:take(1)
		assert.equal(string.byte(c), 11)
	end,

	test_ctrl_max_len = function()
		local buf = levee.d.Buffer(4096)
		local s = string.rep("s", 126)
		local err = ws._ctrl(_.ws.encode_pong, buf, s)

		assert(err.is_ws_ECTRLMAX)
	end,
}
