local ffi = require('ffi')

local errors = require("levee.errors")
local rand = require('levee._.rand')
local base64 = require("levee.p.base64")
local sha1 = require("levee.p.sha1")
local Map = require("levee.d.map")


local VERSION = "13"
local GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"


local ws = {}


local function trim(s)
	if s then return (s:gsub("^%s*(.-)%s*$", "%1")) end
end


--
-- Handshake


ws.client_handshake = function(hub, options)
	local s, r = hub:pipe()

	function fail(err)
		s:error(err)
		s:close()
	end

	function handshake()
		options = options or {}
		-- TODO use d.Map as default for headers when supported by caller
		local headers = options.headers or {}

		headers["Upgrade"] = "websocket"
		headers["Connection"] = "Upgrade"
		local key = rand.bytes(16)
		key = ffi.string(key)
		key = base64.encode(key)
		headers["Sec-WebSocket-Key"] = key
		headers["Sec-WebSocket-Version"] = VERSION

		if options.protocols then
			headers["Sec-WebSocket-Protocol"] = options.protocols
		end
		if options.extensions then
			headers["Sec-WebSocket-Extensions"] = options.extensions
		end

		options.headers = headers
		options.procotols = nil
		options.extensions = nil

		s:send(options)

		local err, res = r:recv()
		if err then return r:close() end

		-- we need a 101 to continue the handshake, but, another code doesn't
		-- imply an error. For example, 401 and 3xx are acceptable response
		-- codes that the user will have to handle separately
		if res.code ~= 101 then return s:send({false}) end

		headers = res.headers
		if not headers then
			return fail(errors.ws.HEADER)
		end

		-- test for header presence with the case-insensitive d.Map
		if type(res.headers) == "table" then
			headers = Map()
			for k,v in pairs(res.headers or {}) do
				headers:add(k, v)
			end
		end

		local header = headers["Upgrade"]
		if not header or header:lower() ~= "websocket" then
			return fail(errors.ws.HEADER)
		end

		header = headers["Connection"]
		if not header or header:lower() ~= "upgrade" then
			return fail(errors.ws.HEADER)
		end

		header = headers["Sec-WebSocket-Accept"]
		header = trim(header)
		if not header or header ~= ws.server_key(key) then
			return fail(errors.ws.KEY)
		end

		-- TODO support Sec-WebSocket-Protocol
		-- TODO support Sec-WebSocket-Extensions

		s:send({true})
		s:close()
	end
	hub:spawn(handshake)

	return s, r
end


ws.server_handshake = function(req)
	-- TODO support Origin header
	-- TODO support Sec-WebSocket-Protocol
	-- TODO support Sec-WebSocket-Extensions

	if req.method ~= "GET" then return errors.ws.METHOD end

	headers = req.headers
	if not headers then return errors.ws.HEADER end

	-- test for header presence with the case-insensitive d.Map
	if type(req.headers) == "table" then
		headers = Map()
		for k,v in pairs(req.headers or {}) do
			headers:add(k, v)
		end
	end

	local header = headers["Host"]
	if not header then return errors.ws.HEADER end

	header = headers["Upgrade"]
	if not header or header:lower() ~= "websocket" then
		return errors.ws.HEADER
	end

	header = headers["Connection"]
	if not header or header:lower() ~= "upgrade" then
		return errors.ws.HEADER
	end

	header = headers["Sec-WebSocket-Version"]
	if not header or header ~= VERSION then return errors.ws.VERSION end

	local key = headers["Sec-WebSocket-Key"]
	if not key then return errors.ws.KEY end

	-- TODO use d.Map as default for headers when supported by caller
	headers = {}

	headers["Upgrade"] = "websocket"
	headers["Connection"] = "Upgrade"
	headers["Sec-WebSocket-Accept"] = ws.server_key(key)

	return nil, headers
end


--
-- Message encoding


ws.client_encode = function(buf, s, n)
end


ws.server_encode = function(buf, s, n)
end


ws.client_frame = function(buf, s, n)
end


ws.client_frame_next = function(buf, s, n)
end


ws.client_frame_last = function(buf, s, n)
end


ws.server_frame = function(buf, s, n)
end


ws.server_frame_next = function(buf, s, n)
end


ws.server_frame_last = function(buf, s, n)
end


--
-- Message decoding

ws.client_decode = function(stream)
end


ws.server_decode = function(stream)
end


--
-- Control frames

ws.close = function(buf)
end


ws.ping = function(buf)
end


ws.pong = function(buf)
end


--
-- Helper


ws.server_key = function(key)
	local key = sha1.binary(key..GUID)
	return base64.encode(key)
end


errors.add(20100, "ws", "CONNECTING", "connecting already in progress")
errors.add(20101, "ws", "HEADER", "header is invalid or missing")
errors.add(20102, "ws", "KEY", "websocket key is invalid or missing")
errors.add(20103, "ws", "VERSION", "websocket version is invalid or missing")
errors.add(20104, "ws", "METHOD", "websocket method is not GET")


return ws
