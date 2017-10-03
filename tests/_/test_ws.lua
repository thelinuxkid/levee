local ffi = require('ffi')

local _ = require("levee")._


return {
	test_mask = function()
		local key = ffi.new("uint8_t [?]", 4, 0x55, 0x7f, 0x90, 0x4a)
		local len = 11
		local buf = ffi.new("uint8_t [?]", len, "Hello World")
		local cmp = ffi.new("uint8_t [?]", len, 0x1d, 0x1a, 0xfc, 0x26, 0x3a,
			0x5f, 0xc7, 0x25, 0x27, 0x13, 0xf4)
		cmp = ffi.string(cmp, len)
		assert.equal(_.ws.mask(key, buf, len), cmp)
	end,
}
