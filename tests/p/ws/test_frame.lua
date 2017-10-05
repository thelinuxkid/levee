local levee = require("levee")
local rand = require("levee._.rand")
local Buffer = require("levee.d.buffer")
local frame = require("levee.p.ws.frame")
local parser = require("levee.p.ws.parser")


return {
	test_encode = function()
		local buf = Buffer(4096)
		local err, rc = frame.encode(buf, false, "PONG")

		assert(not err)
		assert.equal(rc, 2)

		local c = buf:take(1)
		assert.equal(string.byte(c), 0x0a)
		c = buf:take(1)
		assert.equal(string.byte(c), 0x00)
		c = buf:take(1)
	end,

	test_encode_length = function()
		local buf = Buffer(4096)
		local err, rc = frame.encode(buf, true, "PING", 11)

		assert(not err)
		assert.equal(rc, 2)

		local c = buf:take(1)
		assert.equal(string.byte(c), 0x89)
		c = buf:take(1)
		assert.equal(string.byte(c), 0x0b)
		c = buf:take(1)
	end,

	test_encode_key = function()
		local k = rand.bytes(4)
		local buf = Buffer(4096)
		local err, rc = frame.encode(buf, true, "PING", 11, k)

		assert(not err)
		assert.equal(rc, 6)

		local c = buf:take(1)
		assert.equal(string.byte(c), 0x89)
		c = buf:take(1)
		assert.equal(string.byte(c), 0x8b)
		c = buf:take(1)
		assert.equal(string.byte(c), k[0])
		c = buf:take(1)
		assert.equal(string.byte(c), k[1])
		c = buf:take(1)
		assert.equal(string.byte(c), k[2])
		c = buf:take(1)
		assert.equal(string.byte(c), k[3])
	end,

	test_encode_0_len = function()
		local buf = Buffer(4096)
		local err = frame.encode(buf, true, "BINARY")

		assert(not err)
		assert.equal(buf.len, 2)

		local c = buf:take(1)
		assert.equal(string.byte(c), 130)
		c = buf:take(1)
		assert.equal(string.byte(c), 0)
	end,

	test_encode_8bit_len = function()
		local buf = Buffer(4096)
		local err = frame.encode(buf, true, "BINARY", 11)

		assert(not err)
		assert.equal(buf.len, 2)

		local c = buf:take(1)
		assert.equal(string.byte(c), 130)
		c = buf:take(1)
		assert.equal(string.byte(c), 11)
	end,

	test_encode_16bit_len = function()
		local buf = Buffer(4096)
		local err = frame.encode(buf, true, "BINARY", 0xfff)

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
		local buf = Buffer(4096)
		local err = frame.encode(buf, true, "BINARY", 0xffffff)

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
		local buf = Buffer(4096)
		local err = frame.encode(buf, true, "BINARY", 0x0fffffffffffffff+1)

		assert(err.is_ws_ELENMAX)
	end,

	test_decode_meta = function()
		local data = "\xd9\x00"

		local h = levee.Hub()
		local r, w = h.io:pipe()
		local stream = r:stream()
		w:write(data)

		local p = parser()
		p:init()

		local err, f = frame.decode(p, stream)
		assert(not err)
		assert(f.fin)
		assert.equal(f.opcode, "PING")
		assert(not f.n)
		assert(not f.masked)
	end,

	test_decode_paylen_short = function()
		local data = "\xd9\x0b\x48\x65\x6c\x6c\x6f\x20\x57\x6f\x72\x6c\x64"

		local h = levee.Hub()
		local r, w = h.io:pipe()
		local stream = r:stream()
		w:write(data)

		local p = parser()
		p:init()

		local err, f = frame.decode(p, stream)
		assert(not err)
		assert(f.fin)
		assert.equal(f.opcode, "PING")
		assert.equal(f.n, 11)
		assert(not f.masked)
		assert.equal(f.s, "Hello World")
	end,

	test_decode_paylen_long = function()
		local data = "\xd9\x7e\x03\xe8"..string.rep("s", 1000)

		local h = levee.Hub()
		local r, w = h.io:pipe()
		local stream = r:stream()
		w:write(data)

		local p = parser()
		p:init()

		local err, f = frame.decode(p, stream)
		assert(not err)
		assert(f.fin)
		assert.equal(f.opcode, "PING")
		assert.equal(f.n, 1000)
		assert(not f.masked)
		assert.equal(f.s, string.rep("s", 1000))
	end,

	test_decode_paylen_masked = function()
		local data = "\xd9\x8b\x55\x7f\x90\x4a\x1d\x1a\xfc\x26\x3a\x5f\xc7\x25\x27\x13\xf4"

		local h = levee.Hub()
		local r, w = h.io:pipe()
		local stream = r:stream()
		w:write(data)

		local p = parser()
		p:init()

		local err, f = frame.decode(p, stream)
		assert(not err)
		assert(f.fin)
		assert.equal(f.opcode, "PING")
		assert.equal(f.n, 11)
		assert(f.masked)
		assert.equal(f.s, "Hello World")
	end,
}
