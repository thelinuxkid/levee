local ffi = require('ffi')

local levee = require("levee")
local Buffer = require("levee.d.buffer")
local ws = require("levee.p.ws")
local encoder = require("levee.p.ws.encoder")


return {
	test_server_encode = function()
		local buf = Buffer(4096)
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
		local buf = Buffer(4096)
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
		local buf = Buffer(4096)
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
		local buf = Buffer(4096)
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
		local buf = Buffer(4096)
		local err = ws.client_encode(buf, "Hello World")

		assert(not err)
		assert.equal(buf.len, 17)

		local c = buf:take(1)
		assert.equal(string.byte(c), 130)
		c = buf:take(1)
		assert.equal(string.byte(c), 139)
		local k = buf:take(4)
		c = buf:take(11)
		assert.equal(encoder.mask(k, c, 11), "Hello World")
	end,

	test_client_frame = function()
		local buf = Buffer(4096)
		local err = ws.client_frame(buf, "Hello World")

		assert(not err)
		assert.equal(buf.len, 17)

		local c = buf:take(1)
		assert.equal(string.byte(c), 2)
		c = buf:take(1)
		assert.equal(string.byte(c), 139)
		local k = buf:take(4)
		c = buf:take(11)
		assert.equal(encoder.mask(k, c, 11), "Hello World")
	end,

	test_client_frame_next = function()
		local buf = Buffer(4096)
		local err = ws.client_frame_next(buf, "Hello World")

		assert(not err)
		assert.equal(buf.len, 17)

		local c = buf:take(1)
		assert.equal(string.byte(c), 0)
		c = buf:take(1)
		assert.equal(string.byte(c), 139)
		local k = buf:take(4)
		c = buf:take(11)
		assert.equal(encoder.mask(k, c, 11), "Hello World")
	end,

	test_client_frame_last = function()
		local buf = Buffer(4096)
		local err = ws.client_frame_last(buf, "Hello World")

		assert(not err)
		assert.equal(buf.len, 17)

		local c = buf:take(1)
		assert.equal(string.byte(c), 128)
		c = buf:take(1)
		assert.equal(string.byte(c), 139)
		local k = buf:take(4)
		c = buf:take(11)
		assert.equal(encoder.mask(k, c, 11), "Hello World")
	end,

	test_client_close = function()
		local buf = Buffer(4096)
		local err = ws.client_close(buf, C.SP_WS_STATUS_AWAY)

		assert(not err)
		assert.equal(buf.len, 20)

		local c = buf:take(1)
		assert.equal(string.byte(c), 136)
		c = buf:take(1)
		assert.equal(string.byte(c), 142)
		local k = ws._masking_key(buf:take(4))
		c = buf:take(14)
		c = encoder.mask(k, c, 14)
		assert.equal(string.sub(c, 5, 14), "Going Away")
	end,

	test_server_close = function()
		local buf = Buffer(4096)
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
		local buf = Buffer(4096)
		local err = ws.client_ping(buf)

		assert(not err)
		assert.equal(buf.len, 6)

		local c = buf:take(1)
		assert.equal(string.byte(c), 137)
		c = buf:take(1)
		assert.equal(string.byte(c), 128)
	end,

	test_client_ping_body = function()
		local buf = Buffer(4096)
		local err = ws.client_ping(buf, "Hello World")

		assert(not err)
		assert.equal(buf.len, 17)

		local c = buf:take(1)
		assert.equal(string.byte(c), 137)
		local c = buf:take(1)
		assert.equal(string.byte(c), 139)
		local k = ws._masking_key(buf:take(4))
		c = buf:take(11)
		assert.equal(encoder.mask(k, c, 11), "Hello World")
	end,

	test_server_ping = function()
		local buf = Buffer(4096)
		local err = ws.server_ping(buf)

		assert(not err)
		assert.equal(buf.len, 2)

		local c = buf:take(1)
		assert.equal(string.byte(c), 137)
		c = buf:take(1)
		assert.equal(string.byte(c), 0)
	end,

	test_server_ping_body = function()
		local buf = Buffer(4096)
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
		local buf = Buffer(4096)
		local err = ws.client_pong(buf)

		assert(not err)
		assert.equal(buf.len, 6)

		local c = buf:take(1)
		assert.equal(string.byte(c), 138)
		c = buf:take(1)
		assert.equal(string.byte(c), 128)
	end,

	test_client_pong_body = function()
		local buf = Buffer(4096)
		local err = ws.client_pong(buf, "Hello World")

		assert(not err)
		assert.equal(buf.len, 17)

		local c = buf:take(1)
		assert.equal(string.byte(c), 138)
		local c = buf:take(1)
		assert.equal(string.byte(c), 139)
		local k = ws._masking_key(buf:take(4))
		c = buf:take(11)
		assert.equal(encoder.mask(k, c, 11), "Hello World")
	end,

	test_server_pong = function()
		local buf = Buffer(4096)
		local err = ws.server_pong(buf)

		assert(not err)
		assert.equal(buf.len, 2)

		local c = buf:take(1)
		assert.equal(string.byte(c), 138)
		c = buf:take(1)
		assert.equal(string.byte(c), 0)
	end,

	test_server_pong_body = function()
		local buf = Buffer(4096)
		local err = ws.server_pong(buf, "Hello World")

		assert(not err)
		assert.equal(buf.len, 13)

		local c = buf:take(1)
		assert.equal(string.byte(c), 138)
		c = buf:take(1)
		assert.equal(string.byte(c), 11)
	end,

	test_ctrl_max_len = function()
		local buf = Buffer(4096)
		local s = string.rep("s", 126)
		local err = ws._ctrl(encoder.encode_pong, buf, s)

		assert(err.is_ws_ECTRLMAX)
	end,

	test_server_decode = function()
		local data = "\xd9\x8b\x55\x7f\x90\x4a\x1d\x1a\xfc\x26\x3a\x5f\xc7\x25\x27\x13\xf4"

		local h = levee.Hub()
		local r, w = h.io:pipe()
		local stream = r:stream()
		w:write(data)

		local err, f = ws.server_decode(stream)
		assert(not err)
		assert(f.fin)
		assert.equal(f.opcode, "PING")
		assert.equal(f.n, 11)
		assert(f.masked)
		assert.equal(f.s, "Hello World")
	end,

	test_server_decode_unmasked = function()
		local data = "\xd9\x0b\x48\x65\x6c\x6c\x6f\x20\x57\x6f\x72\x6c\x64"

		local h = levee.Hub()
		local r, w = h.io:pipe()
		local stream = r:stream()
		w:write(data)

		local err, f = ws.server_decode(stream)
		assert(err.is_ws_UNMASKED)
	end,

	test_client_decode = function()
		local data = "\xd9\x0b\x48\x65\x6c\x6c\x6f\x20\x57\x6f\x72\x6c\x64"

		local h = levee.Hub()
		local r, w = h.io:pipe()
		local stream = r:stream()
		w:write(data)

		local err, f = ws.client_decode(stream)
		assert(not err)
		assert(f.fin)
		assert.equal(f.opcode, "PING")
		assert.equal(f.n, 11)
		assert(not f.masked)
		assert.equal(f.s, "Hello World")
	end,

	test_client_decode_masked = function()
		local data = "\xd9\x8b\x55\x7f\x90\x4a\x1d\x1a\xfc\x26\x3a\x5f\xc7\x25\x27\x13\xf4"

		local h = levee.Hub()
		local r, w = h.io:pipe()
		local stream = r:stream()
		w:write(data)

		local err, f = ws.client_decode(stream)
		assert(err.is_ws_MASKED)
	end,
}
