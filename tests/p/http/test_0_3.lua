return {
	test_basic = function()
		local levee = require("levee")
		local h = levee.Hub()

		local err, serve = h.http:listen()
		local err, addr = serve:addr()

		local err, c = h.tcp:connect(addr:port())
		c:write(
			"" ..
			"GET /some/path HTTP/1.1\r\n" ..
			"H1: one\r\n" ..
			"Repeat: first\r\n" ..
			"Repeat: second\r\n" ..
			"\r\n")

		local err, s = serve:recv()
		local err, req = s:recv()

		assert.equal(req.method, "GET")
		assert.equal(req.path, "/some/path")
		assert.same(req.headers, {H1 = "one", Repeat = { "first", "second" }})

		req.response:send({levee.HTTPStatus(200), {}, "Hello world\n"})

		local buf = levee.d.Buffer(4096)
		local err = c:readinto(buf)
		assert(#buf > 0)

		s:close()
		serve:close()
		c:readinto(buf)
		assert(not h:in_use())
	end,

	test_core = function()
		local levee = require("levee")

		local h = levee.Hub()

		local err, serve = h.http:listen()
		local err, addr = serve:addr()

		local err, c = h.http:connect(addr:port())
		local err, response = c:get("/path", { headers = {
			H1 = "one",
			Repeat = { "first", "second" }
		}})

		local err, s = serve:recv()
		local err, req = s:recv()
		assert.equal(req.method, "GET")
		assert.equal(req.path, "/path")
		assert(req.headers["Host"])
		assert(req.headers["User-Agent"])
		assert(req.headers["Accept"])
		assert.same(req.headers["H1"], "one")
		assert.same(req.headers["Repeat"], { "first", "second" })
		req.response:send({levee.HTTPStatus(200), { H1 = "one", Repeat = { "first", "second" }}, "Hello world\n"})

		local err, response = response:recv()
		assert.equal(response.code, 200)
		assert.same(response.headers["H1"], "one")
		assert.same(response.headers["Repeat"], { "first", "second" })
		assert.equal(response.body:tostring(), "Hello world\n")

		-- make another request on the same connection
		local err, response = c:get("/path")

		local err, req = s:recv()
		assert.equal(req.method, "GET")
		assert.equal(req.path, "/path")
		req.response:send({levee.HTTPStatus(200), {}, "Hello world\n"})

		local err, response = response:recv()
		assert.equal(response.code, 200)
		assert.equal(response.body:tostring(), "Hello world\n")

		c:close()
		serve:close()
		assert(not h:in_use())
	end,

	test_tls = function()
		local levee = require("levee")
		local _ = levee._
		local filename = debug.getinfo(1, 'S').source:sub(2)
		local path = _.path.dirname(filename)
		local path = _.path.join(path, "..", "..", "mock", "tls")

		local SERVER_OPTIONS = {
			key_file=path.."/key", cert_file=path.."/key.pub"}

		local CLIENT_OPTIONS = {
			server_name="www.imgix.com", ca_file=path.."/key.pub"}

		local h = levee.Hub()

		local err, serve = h.http:listen({tls=SERVER_OPTIONS})
		local err, addr = serve:addr()

		local err, c =  h.http:connect({port=addr:port(), tls=CLIENT_OPTIONS})
		local err, response = c:get("/path", {headers={H1="one"}})

		local err, s = serve:recv()
		local err, req = s:recv()
		assert.equal(req.path, "/path")
		assert.same(req.headers["H1"], "one")
		req.response:send({levee.HTTPStatus(200), {H2="two"}, "Hello world\n"})

		local err, response = response:recv()
		assert.equal(response.code, 200)
		assert.same(response.headers["H2"], "two")
		assert.equal(response.body:tostring(), "Hello world\n")

		c:close()
		serve:close()
		assert(not h:in_use())
	end,

	test_post = function()
		local levee = require("levee")

		local h = levee.Hub()

		local err, serve = h.http:listen()
		local err, addr = serve:addr()

		local err, c = h.http:connect(addr:port())
		local err, response = c:post("/path", {data="foo"})

		local err, s = serve:recv()
		local err, req = s:recv()
		assert.equal(req.method, "POST")
		assert.equal(req.path, "/path")
		assert.equal(req.body:tostring(), "foo")
		req.response:send({levee.HTTPStatus(200), {}, "Hello world\n"})

		local err, response = response:recv()
		assert.equal(response.code, 200)
		assert.equal(response.body:tostring(), "Hello world\n")

		c:close()
		serve:close()
		assert(not h:in_use())
	end,

	test_content_length = function()
		local levee = require("levee")

		local h = levee.Hub()

		local err, serve = h.http:listen()
		local err, addr = serve:addr()

		local err, c = h.http:connect(addr:port())
		local err, response = c:get("/path")

		local err, s = serve:recv()
		local err, req = s:recv()
		local body = "Hello world\n"
		req.response:send({levee.HTTPStatus(200), {}, #body})

		local err, response = response:recv()
		assert.equal(response.code, 200)

		req.conn:send(body)
		assert.equal(response.body:tostring(), "Hello world\n")

		c:close()
		serve:close()
		assert(not h:in_use())
	end,

	test_chunk_transfer = function()
		local levee = require("levee")

		local h = levee.Hub()

		local err, serve = h.http:listen()
		local err, addr = serve:addr()

		local err, c = h.http:connect(addr:port())
		local err, response = c:get("/path")

		local err, s = serve:recv()
		local err, req = s:recv()
		local body = "Hello world\n"
		req.response:send({levee.HTTPStatus(200), {}, nil})

		local err, response = response:recv()
		assert.equal(response.code, 200)
		assert(not response.body)
		assert(response.chunks)

		-- send chunk 1
		req.response:send(17)
		req.conn:send("01234567012345678")
		local err, chunk = response.chunks:recv()
		assert.equal(chunk:tostring(), "01234567012345678")

		-- send chunk 2
		req.response:send("90123456701234567")
		local err, chunk = response.chunks:recv()
		assert.equal(chunk:tostring(), "90123456701234567")

		-- end response
		req.response:close()
		assert.equal(response.chunks:recv(), levee.errors.CLOSED)

		c:close()
		serve:close()
		assert(not h:in_use())
	end,

	test_head = function()
		local levee = require("levee")

		local h = levee.Hub()

		local err, serve = h.http:listen()
		local err, addr = serve:addr()

		local err, c = h.http:connect(addr:port())
		local err, s = serve:recv()

		-- repeat to ensure nothing gets blocked
		for __ = 1, 10 do
			local err, res = c:head("/foo")
			local err, req = s:recv()
			req.response:send({levee.HTTPStatus(200), {}, "1234567890"})
			local err, res = res:recv()
			assert.equal(res.headers["Content-Length"], "10")

			local err, res = c:head("/foo")
			local err, req = s:recv()
			req.response:send({levee.HTTPStatus(200), {}, 10})
			local err, res = res:recv()
			assert.equal(res.headers["Content-Length"], "10")

			local err, res = c:head("/foo")
			local err, req = s:recv()
			req.response:send({levee.HTTPStatus(200), {}, nil})
			local err, res = res:recv()
			assert.equal(res.headers["Transfer-Encoding"], "chunked")
		end

		assert(not next(c.response_to_request))

		c:close()
		serve:close()
		assert(not h:in_use())
	end,

	test_proxy = function(h)
		local levee = require("levee")
		local h = h or levee.Hub()

		local function run()
			-- origin
			local err, origin = h.http:listen()
			local err, origin_addr = origin:addr()
			h:spawn(function()
				for conn in origin do
					h:spawn(function()
						for req in conn do
							req.response:send({levee.HTTPStatus(200), {}, 10000})
							for i = 1, 10 do
								req.conn:write(("."):rep(1000))
								h:continue()
							end
							req.response:close()
						end
					end)
				end
			end)

			-- proxy
			local err, proxy = h.http:listen()
			local err, proxy_addr = proxy:addr()
			h:spawn(function()
				for conn in proxy do
					h:spawn(function()
						local err, backend = h.http:connect(origin_addr:port())
						for req in conn do
							local err, res = backend:get(req.path)
							local err, res = res:recv()
							req.response:send({levee.HTTPStatus(res.code), {}, #res.body})
							res.body:splice(req.conn)
							req.response:close()
						end
						backend:close()
					end)
				end
			end)

			-- client
			local err, c = h.http:connect(proxy_addr:port())

			local err, response = c:get("/")
			local err, response = response:recv()
			assert.equal(response.code, 200)
			assert(#response.body:tostring() == 10000)

			local err, response = c:get("/")
			local err, response = response:recv()
			assert.equal(response.code, 200)
			assert(#response.body:tostring() == 10000)

			c:close()
			proxy:close()
			origin:close()
			h:sleep(100)
			assert(not h:in_use())
		end

		for i = 1, 1 do
			run()
		end
	end,

	test_sendfile = function()
		local levee = require("levee")

		local h = levee.Hub()

		local err, serve = h.http:listen()
		local err, addr = serve:addr()
		h:spawn(function()
			for conn in serve do
				h:spawn(function()
					for req in conn do req:sendfile(req.path) end
				end)
			end
		end)

		local err, c = h.http:connect(addr:port())

		local err, res = c:get("/")
		local err, res = res:recv()
		assert.equal(res.code, 404)
		assert.equal(res.body:tostring(), "Not Found\n")

		local filename = debug.getinfo(1, 'S').source:sub(2)
		local err, res = c:get(filename)
		local err, res = res:recv()
		assert.equal(res.code, 200)
		assert(res.body:tostring():find("wombat"))

		c:close()
		serve:close()
		assert(not h:in_use())
	end,

	test_connect_fail = function()
		local levee = require("levee")
		local h = levee.Hub()
		local err, conn = h.http:connect(50000)
		assert(err)
	end,

	test_conveniences_content_length = function()
		local levee = require("levee")

		local h = levee.Hub()

		local err, serve = h.http:listen()
		local err, addr = serve:addr()
		h:spawn(function()
			local err, s = serve:recv()
			for req in s do
				req.response:send({levee.HTTPStatus(200), {}, '{"foo": "bar"}'})
			end
		end)

		local err, c = h.http:connect(addr:port())

		local err, res = c:get("/")
		local err, res = res:recv()
		assert.equal(res.code, 200)
		assert.same({res:discard()}, {nil, 14})

		local err, res = c:get("/")
		local err, res = res:recv()
		assert.equal(res.code, 200)
		assert.equal(res:tostring(), '{"foo": "bar"}')

		local err, res = c:get("/")
		local err, res = res:recv()
		assert.equal(res.code, 200)
		local err, buf = res:tobuffer()
		assert.equal(buf:peek(), '{"foo": "bar"}')

		local err, res = c:get("/")
		local err, res = res:recv()
		assert.equal(res.code, 200)
		assert.same({res:json()}, {nil, {foo = "bar"}})

		local tmp = os.tmpname()
		local err, res = c:get("/")
		local err, res = res:recv()
		assert.equal(res.code, 200)
		res:save(tmp)
		assert.equal(io.open(tmp):read(), '{"foo": "bar"}')
		os.remove(tmp)

		c:close()
		serve:close()
		assert(not h:in_use())
	end,

	test_conveniences_chunk_transfer = function()
		local levee = require("levee")

		local h = levee.Hub()

		local err, serve = h.http:listen()
		local err, addr = serve:addr()
		h:spawn(function()
			local err, s = serve:recv()
			for req in s do
				req.response:send({levee.HTTPStatus(200), {}, nil})
				req.response:send('{"foo": "')
				req.response:send(5)
				req.conn:write('bar"}')
				req.response:close()
			end
		end)

		local err, c = h.http:connect(addr:port())

		local err, res = c:get("/")
		local err, res = res:recv()
		assert.equal(res.code, 200)
		assert.same({res:discard()}, {nil, 14})

		local err, res = c:get("/")
		local err, res = res:recv()
		assert.equal(res.code, 200)
		assert.equal(res:tostring(), '{"foo": "bar"}')

		local err, res = c:get("/")
		local err, res = res:recv()
		assert.equal(res.code, 200)
		local err, buf = res:tobuffer()
		assert.equal(buf:peek(), '{"foo": "bar"}')

		local err, res = c:get("/")
		local err, res = res:recv()
		assert.equal(res.code, 200)
		assert.same({res:json()}, {nil, {foo = "bar"}})

		local tmp = os.tmpname()
		local err, res = c:get("/")
		local err, res = res:recv()
		assert.equal(res.code, 200)
		res:save(tmp)
		assert.equal(io.open(tmp):read(), '{"foo": "bar"}')
		os.remove(tmp)

		c:close()
		serve:close()
		assert(not h:in_use())
	end,

	test_chunk_spanning = function()
		local levee = require("levee")

		local h = levee.Hub()

		local err, serve = h.http:listen()
		local err, addr = serve:addr()

		local err, c = h.http:connect(addr:port())
		local err, res = c:get("/path")

		local err, s = serve:recv()
		local err, req = s:recv()

		req.response:send({levee.HTTPStatus(200), {}, nil})
		local err, res = res:recv()

		-- send chunk 1
		req.response:send(17)
		req.conn:write("0123456701-34567-")

		local err, chunk = res.chunks:recv()
		chunk:readin(10)
		chunk:trim(10)
		chunk.done:close()  -- leave bytes in the buffer

		-- send chunk 2
		req.response:send("90123456701234567")
		local err, chunk = res.chunks:recv()
		assert.equal(chunk:tostring(), "-34567-90123456701234567")

		-- end response
		req.response:close()
		assert.equal(res.chunks:recv(), levee.errors.CLOSED)

		c:close()
		serve:close()
		assert(not h:in_use())
	end,

	test_connection_dropped = function()
		local levee = require("levee")

		local h = levee.Hub()

		local err, serve = h.http:listen()
		local err, addr = serve:addr()

		local err, c = h.http:connect(addr:port())
		local err, res = c:get("/path")

		local err, s = serve:recv()
		local err, req = s:recv()

		-- drop server connection
		s.conn:close()
		req.response:send({levee.HTTPStatus(200), {}, nil})
		local err = req.response:send(17)
		assert(err)

		-- assert client is signaled
		local err = res:recv()
		assert(err)
	end,

	test_connect_timeout = function()
		local levee = require("levee")
		local h = levee.Hub()
		local err, c = h.http:connect(8003, "10.244.245.246", {connect_timeout=20})
		assert.equal(err, levee.errors.TIMEOUT)
	end,

	test_client_upgrade = function()
		local ws = require("levee.p.ws")
		local levee = require("levee")
		local h = levee.Hub()

		local err, serve = h.http:listen()
		local err, addr = serve:addr()

		local err, c = h.http:connect(addr:port())
		local err, response = c:upgrade("/chat")

		local err, s = serve:recv()
		local err, req = s:recv()
		assert.equal(req.method, "GET")
		assert.equal(req.path, "/chat")
		assert(req.headers["Host"])
		assert.equal(req.headers["Upgrade"], "websocket")
		assert.equal(req.headers["Connection"], "Upgrade")
		assert.equal(req.headers["Sec-WebSocket-Version"], "13")
		assert(req.headers["Sec-WebSocket-Key"])

		local headers = {
			Upgrade="Websocket",
			Connection="UPGRADE",
			["Sec-WebSocket-Accept"]=ws.server_key(req.headers["Sec-WebSocket-Key"]),
		}
		req.response:send({levee.HTTPStatus(101), headers})

		local err, response = response:recv()
		assert.equal(response.code, 101)
		assert.equal(c.ws_state, "OPEN")
	end,

	test_client_upgrade_headers = function()
		local ws = require("levee.p.ws")
		local levee = require("levee")
		local h = levee.Hub()

		local err, serve = h.http:listen()
		local err, addr = serve:addr()

		local err, c = h.http:connect(addr:port())
		local options = {}
		options.protocols = "chat, superchat"
		options.extensions = "foo, bar; baz=2"
		options.headers = {fee="fi"}
		local err, response = c:upgrade("/chat", options)

		local err, s = serve:recv()
		local err, req = s:recv()
		assert.equal(req.method, "GET")
		assert.equal(req.path, "/chat")
		assert(req.headers["Host"])
		assert.equal(req.headers["fee"], "fi")
		assert.equal(req.headers["Upgrade"], "websocket")
		assert.equal(req.headers["Connection"], "Upgrade")
		assert.equal(req.headers["Sec-WebSocket-Version"], "13")
		assert(req.headers["Sec-WebSocket-Key"])
		assert.equal(req.headers["Sec-WebSocket-Protocol"], "chat, superchat")
		assert.equal(req.headers["Sec-WebSocket-Extensions"], "foo, bar; baz=2")

		local headers = {
			Upgrade="Websocket",
			Connection="UPGRADE",
			["Sec-WebSocket-Accept"]=ws.server_key(req.headers["Sec-WebSocket-Key"]),
		}
		req.response:send({levee.HTTPStatus(101), headers})

		local err, response = response:recv()
		assert.equal(response.code, 101)
		assert.equal(c.ws_state, "OPEN")
	end,

	test_client_upgrade_connecting = function()
		local ws = require("levee.p.ws")
		local levee = require("levee")
		local h = levee.Hub()

		local err, serve = h.http:listen()
		local err, addr = serve:addr()

		local err, c = h.http:connect(addr:port())
		local err, response = c:upgrade("/")
		local err = c:upgrade("/")
		assert(err.is_ws_CONNECTING)
	end,

	test_client_upgrade_server_error = function()
		local ws = require("levee.p.ws")
		local levee = require("levee")
		local h = levee.Hub()

		local err, serve = h.http:listen()
		local err, addr = serve:addr()

		local err, c = h.http:connect(addr:port())
		local err, response = c:upgrade("/")

		local err, s = serve:recv()
		local err, req = s:recv()
		req.response:send({levee.HTTPStatus(400), {}})

		local err, response = response:recv()
		assert.equal(response.code, 400)
		assert(not c.ws_state)
	end,

	test_client_upgrade_header_error = function()
		local ws = require("levee.p.ws")
		local levee = require("levee")
		local h = levee.Hub()

		local err, serve = h.http:listen()
		local err, addr = serve:addr()

		local err, c = h.http:connect(addr:port())
		local err, response = c:upgrade("/")

		local err, s = serve:recv()
		local err, req = s:recv()
		req.response:send({levee.HTTPStatus(101), {Upgrade="bad"}})

		local err, response = response:recv()
		assert(err.is_ws_HEADER)
		assert(not c.ws_state)
	end,

	test_client_upgrade_key_error = function()
		local ws = require("levee.p.ws")
		local levee = require("levee")
		local h = levee.Hub()

		local err, serve = h.http:listen()
		local err, addr = serve:addr()

		local err, c = h.http:connect(addr:port())
		local err, response = c:upgrade("/")

		local err, s = serve:recv()
		local err, req = s:recv()

		local headers = {
			Upgrade="websocket",
			Connection="upgrade",
			["Sec-WebSocket-Accept"]="bad",
		}
		req.response:send({levee.HTTPStatus(101), headers})

		local err = response:recv()
		assert(err.is_ws_KEY)
		assert(not c.ws_state)
	end,
}
