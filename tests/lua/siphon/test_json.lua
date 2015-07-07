return {
	test_core = function()
		-- streaming Conn stub
		local conn = {
			stream = {
				'{"int": 3, "f',
				'oo": "bar", "neste',
				'd": {"alist": ',
				'[1, 2, 3], "yes": tr',
				'ue, "no": false}}{',
				'"foo": "bar"}', }}
		conn.__index = conn

		function conn:readinto(buf)
			local s = table.remove(self.stream, 1)
			if not s then
				return -1
			end
			buf:push_s(s)
			return #s
		end
		--

		local levee = require("levee")

		local buf = levee.buffer(4096)
		local parser = levee.json()

		local ok, got = parser:stream_consume(conn, buf)
		assert(ok)
		assert.same(got, {
			int = 3,
			-- foo
		  oo = "bar",
			-- nested
			d = {
				alist = {1, 2, 3},
				yes = true,
				no = false, } })

		local ok, got = parser:stream_consume(conn, buf)
		assert(ok)
		assert.same(got, {foo = "bar"})

		local ok, got = parser:stream_consume(conn, buf)
		assert(not ok)
	end,
}