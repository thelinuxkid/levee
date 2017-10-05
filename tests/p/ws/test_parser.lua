local ffi = require('ffi')

local levee = require("levee")
local parser = require("levee.p.ws.parser")


return {
	test_decode_meta = function()
		local frame = "\xd9\x00"
		local buf = ffi.cast("char*", frame)

		local p = parser()
		p:init()

		local err, rc = p:next(buf, 1)
		assert(not err)
		assert.equal(rc, 0)

		local err, rc = p:next(buf, 2)
		assert(not err)
		assert.equal(rc, 2)
		assert.equal(p:is_done(), true)
		assert.same({p:value(buf)}, {true, "PING", false, nil})
	end,

	test_decode_paylen_7 = function()
		local frame = "\xd9\x0b\x48\x65\x6c\x6c\x6f\x20\x57\x6f\x72\x6c\x64"
		local buf = ffi.cast("char*", frame)

		local p = parser()
		p:init()

		local err, rc = p:next(buf, 1)
		assert(not err)
		assert.equal(rc, 0)

		local err, rc = p:next(buf, 2)
		assert(not err)
		assert.equal(rc, 2)
		assert.equal(p:is_done(), false)
		assert.same({p:value(buf)}, {true, "PING", false, 11})
		buf = buf + rc

		local err, rc = p:next(buf, 5)
		assert(not err)
		assert.equal(rc, 5)
		assert.equal(p:is_done(), false)
		assert.equal(p:value(buf, 5), "Hello")
		buf = buf + rc

		local err, rc = p:next(buf, 6)
		assert(not err)
		assert.equal(rc, 6)
		assert.equal(p:is_done(), true)
		assert.equal(p:value(buf, 6), " World")
	end,

	test_decode_paylen_16 = function()
		local frame = "\xd9\x7e\x03\xe8"..string.rep("s", 1000)
		local buf = ffi.cast("char*", frame)

		local p = parser()
		p:init()

		local err, rc = p:next(buf, 1)
		assert(not err)
		assert.equal(rc, 0)

		local err, rc = p:next(buf, 2)
		assert(not err)
		assert.equal(rc, 2)
		assert.equal(p:is_done(), false)
		assert.same({p:value(buf)}, {true, "PING", false, nil})
		buf = buf + rc

		local err, rc = p:next(buf, 2)
		assert(not err)
		assert.equal(rc, 2)
		assert.equal(p:is_done(), false)
		assert.same(p:value(buf), 1000)
		buf = buf + rc

		local err, rc = p:next(buf, 1000)
		assert(not err)
		assert.equal(rc, 1000)
		assert.equal(p:is_done(), true)
		assert.same(p:value(buf), string.rep("s", 1000))
	end,

	test_decode_paylen_64 = function()
		local frame = "\xd9\x7f\x00\xff\xff\xff\xff\xff\xff\xfe"
		local buf = ffi.cast("char*", frame)

		local p = parser()
		p:init()

		local err, rc = p:next(buf, 1)
		assert(not err)
		assert.equal(rc, 0)

		local err, rc = p:next(buf, 2)
		assert(not err)
		assert.equal(rc, 2)
		assert.equal(p:is_done(), false)
		assert.same({p:value(buf)}, {true, "PING", false, nil})
		buf = buf + rc

		local err, rc = p:next(buf, 8)
		assert(not err)
		assert.equal(rc, 8)
		assert.equal(p:is_done(), false)
		assert.same(p:value(buf), 0xfffffffffffffe)
	end,

	test_decode_unmask = function()
		local frame = "\xd9\x8b\x55\x7f\x90\x4a\x1d\x1a\xfc\x26\x3a\x5f\xc7\x25\x27\x13\xf4"
		local buf = ffi.cast("char*", frame)

		local p = parser()
		p:init()

		local err, rc = p:next(buf, 1)
		assert(not err)
		assert.equal(rc, 0)

		local err, rc = p:next(buf, 2)
		assert(not err)
		assert.equal(rc, 2)
		assert.equal(p:is_done(), false)
		assert.same({p:value(buf)}, {true, "PING", true, 11})
		buf = buf + rc

		local err, rc = p:next(buf, 4)
		assert(not err)
		assert.equal(rc, 4)
		assert.equal(p:is_done(), false)
		local k = p:value(buf)
		assert.equal(k[0], 0x55)
		assert.equal(k[1], 0x7f)
		assert.equal(k[2], 0x90)
		assert.equal(k[3], 0x4a)
		buf = buf + rc

		local err, rc = p:next(buf, 5)
		assert(not err)
		assert.equal(rc, 5)
		assert.equal(p:is_done(), false)
		assert.same(p:value(buf, 5), "Hello")
		buf = buf + rc

		local err, rc = p:next(buf, 1)
		assert(not err)
		assert.equal(rc, 1)
		assert.equal(p:is_done(), false)
		assert.same(p:value(buf, 1), " ")
		buf = buf + rc

		local err, rc = p:next(buf, 5)
		assert(not err)
		assert.equal(rc, 5)
		assert.equal(p:is_done(), true)
		assert.same(p:value(buf, 5), "World")
	end,
}
