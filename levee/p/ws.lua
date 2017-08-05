local ffi = require('ffi')

local errors = require("levee.errors")
local rand = require('levee._.rand')
local base64 = require("levee.p.base64")
local sha1 = require("levee.p.sha1")
local Map = require("levee.d.map")


local VERSION = "13"
local GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"


--
-- bit masks. all bit module operations are based on 32-bit integers

local FIN = 0x80000000
local CONT = 0x0
local TEXT = 0x1000000
local BIN = 0x2000000
local CLOSE = 0x8000000
local PING = 0x9000000
local PONG = 0xa000000
local MASK = 0x800000

--
-- constants

local BYTE = 255
local OCTECT = 8
local LEN_16 = 126
local LEN_64 = 127
local LEN_8_MAX = 125
local LEN_16_MAX = 0xffff
local LEN_64_MAX = 0xffffffffffffffff


local ws = {}


local function trim(s)
	if s then return (s:gsub("^%s*(.-)%s*$", "%1")) end
end


local function push(buf, d, n)
	-- push n bytes from d int buf
	-- expects little-endian order
	for i=n-1,0,-1 do
		local m = bit.lshift(BYTE, OCTECT*i)
		local c = bit.band(d, m)
		c = bit.rshift(c, OCTECT*i)
		c = string.char(c)
		buf:push(c)
	end
end


local function encode(buf, fin, mask, n, opcode)
	--      0                   1                   2                   3
	--      0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
	--     +-+-+-+-+-------+-+-------------+-------------------------------+
	--     |F|R|R|R| opcode|M| Payload len |    Extended payload length    |
	--     |I|S|S|S|  (4)  |A|     (7)     |             (16/64)           |
	--     |N|V|V|V|       |S|             |   (if payload len==126/127)   |
	--     | |1|2|3|       |K|             |                               |
	--     +-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - - +
	--     |     Extended payload length continued, if payload len == 127  |
	--     + - - - - - - - - - - - - - - - +-------------------------------+
	--     |                               |Masking-key, if MASK set to 1  |
	--     +-------------------------------+-------------------------------+
	--     | Masking-key (continued)       |          Payload Data         |
	--     +-------------------------------- - - - - - - - - - - - - - - - +
	--     :                     Payload Data continued ...                :
	--     + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
	--     |                     Payload Data continued ...                |
	--     +---------------------------------------------------------------+


	-- note: all bit module operations return 32-bit ints

	-- start with a 32-bit int which is used to encode FIN, RSVs, opcode,
	-- MASK and payload len
	local i = bit.tobit(0)

	--
	-- FIN bit

	if fin then i = bit.bor(FIN) end

	--
	-- RSVs

	-- the next three bits (RSV1, RSV2, RSV3) are set when there are
	-- extensions present
	-- TODO support extensions here

	--
	-- opcode

	-- default frame type is binary
	if not opcode then opcode = BIN end
	i = bit.bor(i, opcode)

	--
	-- MASK

	if mask then i = bit.bor(i, MASK) end

	--
	-- payload len

	-- the value to encode as payload len
	-- if n <= 125 then l = n
	-- if n > 125 and n <= UINT16_MAX then l = 126
	-- if n > UINT16_MAX and n <= UINT64_MAX then l = 127
	local l = n

	-- the number of bytes need to encode the actual length of the
	-- payload (n). This is 2 if n <= 125 else it's 4.
	local b = 2

	if n > LEN_64_MAX then return errors.ws.LENGTH end
	if n > LEN_16_MAX then
		l = LEN_64
		b = 4
	elseif n > LEN_8_MAX then
		l = LEN_16
		b = 4
	end

	-- shift payload len to the appropriate place in our 32-bit int,
	-- i.e., bits 17-23 from the MSB. The MSB of payload len is ignored
	-- since it can only have a value range of 0-127.
	local s = bit.lshift(l, OCTECT*2)
	-- combine the shifted payload len with our 32-bit int
	i = bit.bor(i, s)

	if b == 2 then
		-- leave only the most significant 2 bytes
		i = bit.rshift(i, OCTECT*2)
	end

	if l == LEN_16 then
		-- encode the length of the payload (n) in the last 2 bytes of our
		-- 32-bit int
		i = bit.bor(i, n)
	end

	if l == LEN_64 then
	end

	push(buf, i, b)

	return nil
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
	-- FIN bit set, opcode of TEXT or BIN and data not masked

	if not s then s = "" end
	if not n then n = s:len() end

	local err, i, b = encode(buf, true, false, n)
	if err then return err end

	-- the remainder is extension data + application data (s).
	-- TODO support extensions here
	buf:push(s)
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
errors.add(20104, "ws", "LENGTH", "payload length greater than UINT64")


return ws
