local ffi = require('ffi')

local errors = require("levee.errors")
local rand = require('levee._.rand')
local base64 = require("levee.p.base64")
local ssl = require("levee._.ssl")
local Map = require("levee.d.map")
local _ = require("levee._")


local VERSION = "13"
local GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

local LEN_7_MAX = 125
local LEN_16_MAX = 0xffff
-- the maximum allowed payload length is the maximum value of an unsigned
-- 64-bit with the MSB set to 0.
local LEN_64_MAX = 0x0fffffffffffffff

local HEADER_KEY_LEN = 16


local function trim(s)
	if s then return (s:gsub("^%s*(.-)%s*$", "%1")) end
end


local Frame_mt = {}
Frame_mt.__index = Frame_mt


function Frame_mt:__new()
	return ffi.new(self)
end


local Frame = ffi.metatype("SpWsFrame", Frame_mt)


local ws = {}


--
-- Helper


ws._server_key = function(k)
	k = ssl.sha1(k..GUID)
	return base64.encode(k)
end


ws._push_payload = function(buf, s, k)
	-- pushes the remainder of the frame, i.e., the payload. The payload is
	-- defined as the extension data + the application data (s).

	-- TODO support extensions here
	if k then s = _.ws.mask(k, s, s:len()) end
	buf:push(s)
end


ws._masking_key = function(k)
	-- the masking key is a 32-bit value chosen at random
	if not k then k = rand.bytes(4) end

	local n = ffi.new("uint8_t [4]")
	C.memcpy(n, k, 4)

	return n
end


ws._encode = function(buf, fin, opcode, n, key)
	local f = Frame ()

	f.fin = fin
	-- TODO support extensions here (RSV1, RSV2, RSV3)
	f.opcode = opcode

	if n then
		f.masked = key and true or false

		if n < 0 then return errors.ws.MINLEN end
		if n > LEN_64_MAX then return errors.ws.MAXLEN end

		if n > LEN_16_MAX then
				f.paylen.type = C.SP_WS_LEN_64
				f.paylen.len.u64 = n
		elseif n > LEN_7_MAX then
				f.paylen.type = C.SP_WS_LEN_16
				f.paylen.len.u16 = n
		elseif n > 0 then
				f.paylen.type = C.SP_WS_LEN_7
				f.paylen.len.u7 = n
		else
				f.paylen.type = C.SP_WS_LEN_NONE
		end

		if key then f.mask_key = key  end
	end

	local err, rc = _.ws.encode_frame(buf.buf, f)
	if err then return err end
	buf:bump(rc)
end


ws._client_encode = function(buf, s, fin, opcode)
	local k = ws._masking_key()
	local err = ws._encode(buf, fin, opcode, s:len(), k)
	if err then return err end

	ws._push_payload(buf, s, k)
end


ws._server_encode = function(buf, s, fin, opcode)
	local err = ws._encode(buf, fin, opcode, s:len())
	if err then return err end

	ws._push_payload(buf, s)
end


ws._ctrl_close = function(buf, stat, mask)
	local s = stat and _.ws.status_string(stat) or nil
	local len = s and #s or 0
	local k = mask and ws._masking_key() or nil

	local err, rc = _.ws.encode_close(buf.buf, stat, k, len)
	if err then return err end
	buf:bump(rc)

	if s then ws._push_payload(buf, s, k) end
end


ws._ctrl = function(fn, buf, s, mask)
	local len = s and #s or 0
	local k = mask and ws._masking_key() or nil

	local err, rc = fn(buf.buf, k, len)
	if err then return err end
	buf:bump(rc)

	if s then ws._push_payload(buf, s, k) end
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
	return ws._client_encode(buf, s, true, C.SP_WS_BIN)
end


ws.client_frame = function(buf, s)
	-- FIN bit clear, opcode of TEXT or BIN and data masked
	return ws._client_encode(buf, s, false, C.SP_WS_BIN)
end


ws.client_frame_next = function(buf, s)
	-- FIN bit clear, opcode of CONT and data masked
	return ws._client_encode(buf, s, false, C.SP_WS_CONT)
end


ws.client_frame_last = function(buf, s)
	-- FIN bit set, opcode of CONT and data masked
	return ws._client_encode(buf, s, true, C.SP_WS_CONT)
end


ws.server_encode = function(buf, s)
	-- FIN bit set, opcode of TEXT or BIN and data not masked
	return ws._server_encode(buf, s, true, C.SP_WS_BIN)
end


ws.server_frame = function(buf, s)
	-- FIN bit clear, opcode of TEXT or BIN and data not masked
	return ws._server_encode(buf, s, false, C.SP_WS_BIN)
end


ws.server_frame_next = function(buf, s)
	-- FIN bit clear, opcode of CONT and data not masked
	return ws._server_encode(buf, s, false, C.SP_WS_CONT)
end


ws.server_frame_last = function(buf, s)
	-- FIN bit set, opcode of CONT and data not masked
	return ws._server_encode(buf, s, true, C.SP_WS_CONT)
end


--
-- Message decoding

ws.client_decode = function(stream)
end


ws.server_decode = function(stream)
end


--
-- Control frames

ws.client_close = function(buf, stat)
	-- FIN bit set, opcode of CLOSE and data masked
	return ws._ctrl_close(buf, stat, true)
end


ws.client_ping = function(buf, s)
	-- FIN bit set, opcode of PING and data masked
	return ws._ctrl(_.ws.encode_ping, buf, s, true)
end


ws.client_pong = function(buf, s)
	-- FIN bit set, opcode of PING and data masked
	return ws._ctrl(_.ws.encode_pong, buf, s, true)
end


ws.server_close = function(buf, stat)
	-- FIN bit set, opcode of CLOSE and data not masked
	return ws._ctrl_close(buf, stat, false)
end


ws.server_ping = function(buf, s)
	-- FIN bit set, opcode of PING and data not masked
	return ws._ctrl(_.ws.encode_ping, buf, s)
end


ws.server_pong = function(buf, s)
	-- FIN bit set, opcode of PONG and data not masked
	return ws._ctrl(_.ws.encode_pong, buf, s)
end


errors.add(20100, "ws", "CONNECTING", "connecting already in progress")
errors.add(20101, "ws", "HEADER", "header is invalid or missing")
errors.add(20102, "ws", "KEY", "websocket key is invalid or missing")
errors.add(20103, "ws", "VERSION", "websocket version is invalid or missing")
errors.add(20104, "ws", "METHOD", "websocket method is not GET")
errors.add(20105, "ws", "MAXLEN", "payload length greater than 2^51")
errors.add(20106, "ws", "MINLEN", "payload length less than 0")

return ws
