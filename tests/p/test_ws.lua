local levee = require("levee")
local ws = require("levee.p.ws")

return {
	test_server_encode = function()
		local buf = levee.d.Buffer(4096)
		local s = "Hello World"
		ws.server_encode(buf, s, s:len())

		assert.equal(buf.len, 13)

		-- first byte: 10000010
		local c = buf:take(1)
		assert.equal(string.byte(c), 130)

		-- second byte: 00001011
		c = buf:take(1)
		assert.equal(string.byte(c), 11)

		assert.equal(buf:take(11), "Hello World")
	end,

	test_server_key = function()
		local key = ws.server_key("dGhlIHNhbXBsZSBub25jZQ==")
		assert.equal(key, "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=")
	end,
}
