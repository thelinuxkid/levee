local ffi = require('ffi')

local errors = require("levee.errors")
local rand = require('levee._.rand')
local base64 = require("levee.p.base64")
local sha1 = require("levee.p.sha1")
local Map = require("levee.d.map")


local VERSION = "13"
local GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"


--
-- bit masks. All BitOp extension operations are based on 32-bit integers

local FIN = 0x80000000
local CONT = 0x0
local TEXT = 0x1000000
local BIN = 0x2000000
local CLOSE = 0x8000000
local PING = 0x9000000
local PONG = 0xa000000
local MASK = 0x800000

-- the default data mode. This can be either BIN or TEXT
local MODE = BIN


--
-- constants

local BYTE = 255
local OCTECT = 8
local LEN_8 = 125
local LEN_16 = 126
local LEN_64 = 127
-- the BitOp module strongly advises not to use numbers outside of the
-- -+2^51 range (see http://bitop.luajit.org/semantics.html)
local LEN_MAX = 0x7ffffffffffff

local UINT16_MAX = 0xffff
local UINT32_MAX = 0xffffffff

local HEADER_KEY_LEN = 16
-- The maximum length of the payload of a control frame
local CTRL_MAX = 125


local function trim(s)
	if s then return (s:gsub("^%s*(.-)%s*$", "%1")) end
end


local function nbo(b, n)
	-- returns a table of n bytes from b in network byte order (big-endian)

	-- TODO currently assumes b is in little-endian order
	-- TODO use string.unpack if possible when Lua 5.3 is available to levee
	local bytes = {}
	for i=n-1,0,-1 do
		local m = bit.lshift(BYTE, OCTECT*i)
		local c = bit.band(b, m)
		c = bit.rshift(c, OCTECT*i)
		table.insert(bytes, c)
	end
	return bytes
end


local ws = {
	CONT=CONT,
	TEXT=TEXT,
	BIN=BIN,
	CLOSE=CLOSE,
	PING=PING,
	PONG=PONG,
}


--
-- Helper


ws._server_key = function(k)
	k = sha1.binary(k..GUID)
	return base64.encode(k)
end

ws._masking_key = function(k)
	local m = bit.tobit(0)
	for i=1,k:len() do
		local c = string.sub(k, i, i)
		c = string.byte(c)
		m = bit.lshift(m, OCTECT)
		m = bit.bor(m, c)
	end
	return m
end


ws._mask_payload = function(p, n, k)
	-- applies the masking algorithm to the payload and returns the result

	-- masking algorithm:
	--
	-- octet i of the transformed data ("transformed-octet-i") is the XOR of
	-- octet i of the original data ("original-octet-i") with octet at index
	-- i modulo 4 of the masking key ("masking-key-octet-j"):
	--
	-- j                   = i MOD 4
	-- transformed-octet-i = original-octet-i XOR masking-key-octet-j

	k = nbo(k, 4)
	local m = ""
	for i=1,n do
		local pt = string.sub(p, i, i)
		pt = string.byte(pt)
		local j = (i-1) % 4
		local kt = k[j+1]
		pt = bit.bxor(pt, kt)
		pt = string.char(pt)
		m = m..pt
	end
	return m
end


-- The same algorithm applies regardless of the direction of the
-- translation, i.e., the same steps are applied to mask the payload and
-- unmask the payload
ws._unmask_payload = ws._mask_payload


ws._push_frame = function(buf, b, n)
	-- pushes n chars from b into buf in network byte order (big-endian)
	b = nbo(b, n)
	for _,c in ipairs(b) do
		c = string.char(c)
		buf:push(c)
	end
end


ws._push_payload = function(buf, s, k)
	-- pushes the remainder of the frame, i.e., the payload. The payload is
	-- defined as the extension data + the application data (s).

	-- TODO support extensions here
	if k then s = ws._mask_payload(s, s:len(), k) end
	buf:push(s)
end


ws._encode = function(buf, fin, opcode, mask, n)
	if n < 0 then return errors.ws.MINLEN end
	if n > LEN_MAX then return errors.ws.MAXLEN end

	-- WebSocket data frame:
	--
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


	-- note: all BitOp extension operations return signed 32-bit ints

	-- start with a 32-bit int as the data frame. This is where FIN, RSVs,
	-- opcode, MASK and payload len will be encoded (see figure above)
	local f = bit.tobit(0)

	--
	-- FIN bit

	if fin then f = bit.bor(FIN) end

	--
	-- RSVs

	-- the next three bits (RSV1, RSV2, RSV3) are set when there are
	-- extensions present
	-- TODO support extensions here

	--
	-- opcode

	f = bit.bor(f, opcode)

	--
	-- MASK

	if mask then f = bit.bor(f, MASK) end

	--
	-- payload len

	-- the value to encode as payload len (l). This is different from the
	-- length of the payload (n). Here, UINT64_MAX is the theoretical
	-- max. The practical max for the BitOp module is 2^51 (LEN_MAX):
	-- if n <= 125 then l = n
	-- if n > 125 and n <= UINT16_MAX then l = 126
	-- if n > UINT16_MAX and n <= UINT64_MAX then l = 127
	local l = n

	if n > UINT16_MAX then
		l = LEN_64
	elseif n > LEN_8 then
		l = LEN_16
	end

	-- shift payload len (l) to the appropriate place in the data frame,
	-- i.e., bits 17-23 from the least-significant bit. The most-significant
	-- bit of payload len (l) is ignored since the allowed value range is
	-- 0-127.
	local s = bit.lshift(l, OCTECT*2)
	-- add the shifted payload len (l) to the data frame
	f = bit.bor(f, s)

	if n <= LEN_8 then
		-- the length of the payload (n) is encoded as payload len (l), so, the
		-- least-significant 16 bits of the data frame are not needed
		f = bit.rshift(f, OCTECT*2)
		ws._push_frame(buf, f, 2)
		return
	end

	if l == LEN_16 then
		-- encode the length of the payload (n) in the least-significant 16
		-- bits of the data frame
		f = bit.bor(f, n)
		ws._push_frame(buf, f, 4)
		return
	end

	-- since all BitOp extension operations are based on 32-bit integers,
	-- split the 64-bit length of the payload (n) into two 32-bit ints

	-- The bit.tobit function normalizes numbers outside the 32-bit range by
	-- returning their least-significant 32 bits. This is the first 32-bit
	-- int and the lower half of the 64-bit length of the payload (n)
	local lsb = bit.tobit(n)
	-- BitOp extension operations return *signed* 32-bit integers, but, the
	-- next step requires an unsigned integer
	lsb = ffi.new("uint32_t", lsb)
	lsb = tonumber(lsb)
	-- now get the most-significant 32 bits. This is the second 32-bit int
	-- and the upper half of the 64-bit length of the payload (n)
	local msb = (n - lsb)/UINT32_MAX

	-- split our second 32-bit int further. The most-significant 16 bits of
	-- that result become the least-significant 16 bits of the data frame
	n = bit.rshift(msb, OCTECT*2)
	f = bit.bor(f, n)

	-- push the first 32 bits of the data frame, i.e., the initial 32-bit int
	-- (f)
	ws._push_frame(buf, f, 4)

	-- push the least-significant 16 bits of the result of the last operation
	-- , i.e., bytes 5 and 6 of the 64-bit length of the payload (n), as the
	-- next part of the data frame
	msb = bit.band(msb, UINT16_MAX)
	ws._push_frame(buf, msb, 2)

	-- push the least-siginificant 32 bits of the length of the payload (n)
	-- as the next part of the data frame
	ws._push_frame(buf, lsb, 4)
end


ws._client_encode = function(buf, s, fin, opcode)
	local err = ws._encode(buf, fin, opcode, true, s:len())
	if err then return err end

	-- the masking key is a 32-bit value chosen at random
	local k = rand.integer()
	-- use a BitOp extension operation to ensure a 32-bit integer
	k = bit.tobit(k)

	ws._push_frame(buf, k, 4)
	ws._push_payload(buf, s, k)
end


ws._server_encode = function(buf, s, fin, opcode)
	local err = ws._encode(buf, fin, opcode, false, s:len())
	if err then return err end

	ws._push_payload(buf, s)
end


ws._ctrl = function(buf, s, opcode, mask)
	local n = 0
	if s then n = s:len() end

	if n > CTRL_MAX then return errors.ws.MAXCTRL end
	local err = ws._encode(buf, true, opcode, mask, n)
	if err then return err end

	if s then ws._push_payload(buf, s) end
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
		local key = rand.bytes(HEADER_KEY_LEN)
		key = ffi.string(key, HEADER_KEY_LEN)
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

		-- a 101 response is needed to continue the handshake, but, another
		-- code doesn't imply an error. For example, 401 and 3xx are acceptable
		-- response codes that the user will have to handle separately
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
		if not header or header ~= ws._server_key(key) then
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

	if base64.decode(key):len() ~= 16 then return errors.ws.KEY end

	-- TODO use d.Map as default for headers when supported by caller
	headers = {}

	headers["Upgrade"] = "websocket"
	headers["Connection"] = "Upgrade"
	headers["Sec-WebSocket-Accept"] = ws._server_key(key)

	return nil, headers
end


--
-- Message encoding


ws.client_encode = function(buf, s)
	-- FIN bit set, opcode of TEXT or BIN and data masked
	return ws._client_encode(buf, s, true, MODE)
end


ws.client_frame = function(buf, s)
	-- FIN bit clear, opcode of TEXT or BIN and data masked
	return ws._client_encode(buf, s, false, MODE)
end


ws.client_frame_next = function(buf, s)
	-- FIN bit clear, opcode of CONT and data masked
	return ws._client_encode(buf, s, false, CONT)
end


ws.client_frame_last = function(buf, s)
	-- FIN bit set, opcode of CONT and data masked
	return ws._client_encode(buf, s, true, CONT)
end


ws.server_encode = function(buf, s)
	-- FIN bit set, opcode of TEXT or BIN and data not masked
	return ws._server_encode(buf, s, true, MODE)
end


ws.server_frame = function(buf, s)
	-- FIN bit clear, opcode of TEXT or BIN and data not masked
	return ws._server_encode(buf, s, false, MODE)
end


ws.server_frame_next = function(buf, s)
	-- FIN bit clear, opcode of CONT and data not masked
	return ws._server_encode(buf, s, false, CONT)
end


ws.server_frame_last = function(buf, s)
	-- FIN bit set, opcode of CONT and data not masked
	return ws._server_encode(buf, s, true, CONT)
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


ws.ping = function(buf, s)
	-- FIN bit set, opcode of PING and data not masked

	-- A Ping frame MAY include "Application data"
	-- https://tools.ietf.org/html/rfc6455#section-5.5.2
	return ws._ctrl(buf, s, PING, false)
end


ws.pong = function(buf, s)
	-- FIN bit set, opcode of PING and data not masked

	-- A Pong frame sent in response to a Ping frame must have identical
	-- "Application data" as found in the message body of the Ping frame
	-- being replied to.
	-- https://tools.ietf.org/html/rfc6455#section-5.5.3
	return ws._ctrl(buf, s, PONG, false)
end


errors.add(20100, "ws", "CONNECTING", "connecting already in progress")
errors.add(20101, "ws", "HEADER", "header is invalid or missing")
errors.add(20102, "ws", "KEY", "websocket key is invalid or missing")
errors.add(20103, "ws", "VERSION", "websocket version is invalid or missing")
errors.add(20104, "ws", "METHOD", "websocket method is not GET")
errors.add(20105, "ws", "MAXLEN", "payload length greater than 2^51")
errors.add(20106, "ws", "MINLEN", "payload length less than 0")
errors.add(20107, "ws", "MAXCTRL", "control frame payload length is greater than 125")


return ws
