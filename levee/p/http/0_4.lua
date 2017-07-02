local ffi = require('ffi')
local C = ffi.C
local meta = require("levee.meta")
local Map = require("levee.d.map")
local Encoder = require("levee.p.utf8").Utf8
local Status = require("levee.p.http.status")
local Parser = require("levee.p.http.parse")


local VERSION = "HTTP/1.1"
local FIELD_SEP = ": "
local CRLF = "\r\n"

local USER_AGENT = ("%s/%s"):format(meta.name, meta.version.string)


--
-- Request
--
local Request_mt = {}
Request_mt.__index = Request_mt


function Request_mt:uri()
	-- TODO
end


function Request_mt:__tostring()
	return ("levee.http.0_4.Request: %s %s"):format(self.method, self.path)
end


--
-- Date response header cache

local http_time = ffi.new("time_t [1]")
local http_date = nil
local http_date_buf = ffi.new("char [32]")
local http_tm = ffi.new("struct tm")

local function httpdate()
	local t = C.time(nil)
	if t ~= http_time[0] then
		http_time[0] = t
		C.gmtime_r(http_time, http_tm)
		local len = C.strftime(
			http_date_buf, 32, "%a, %d %b %Y %H:%M:%S GMT", http_tm)
		http_date = ffi.string(http_date_buf, len)
	end
	return http_date
end


--- Returns HEX representation of num
local hexstr = '0123456789abcdef'
function num2hex(num)
	local s = ''
	while num > 0 do
		local mod = math.fmod(num, 16)
		s = string.sub(hexstr, mod+1, mod+1) .. s
		num = math.floor(num / 16)
	end
	if s == '' then s = '0' end
	return s
end


-- TODO make this part of levee.p.uri when it makes sense
local function encode_url(value)
	local e =  Encoder()
	local flag = bit.bor(C.SP_UTF8_URI, C.SP_UTF8_SPACE_PLUS)
	local err, n = e:encode(value, #value, flag)
	if err then return err end
	return nil, ffi.string(e.buf, n)
end


local function encode_headers(buf, headers, nosep)
	if type(headers) == "cdata" then
		-- assume it's a d.Map
		local last = nosep and "" or CRLF
		buf:push(tostring(headers)..last)
		return
	end

	for k, v in pairs(headers) do
		if type(v) == "table" then
			for _,item in pairs(v) do
				buf:push(k..FIELD_SEP..item..CRLF)
			end
		else
			buf:push(k..FIELD_SEP..v..CRLF)
		end
	end
	if not nosep then buf:push(CRLF) end
end


local function add_header(headers, key, value)
	if type(headers) == "cdata" then
		-- assume it's a d.Map
		headers:add(key, value)
		return
	end

	if headers[key] then
		if type(headers[key]) == "string" then
			headers[key] = {headers[key]}
		end
		table.insert(headers[key], value)
	else
		headers[key] = value
	end
end


function encode_request(buf, method, path, params, headers, body)
	if params then
		local s = {path, "?"}
		for key, value in pairs(params) do
			table.insert(s, key)
			table.insert(s, "=")
			table.insert(s, value)
			table.insert(s, "&")
		end
		table.remove(s)
		path = table.concat(s)
	end
	local err, path = encode_url(path)
	if err then return err end

	buf:push(("%s %s %s%s"):format(method, path, VERSION, CRLF))

	if not headers then headers = Map() end
	-- TODO: Host
	if not headers["User-Agent"] then
		add_header(headers, "User-Agent", USER_AGENT)
	end
	if not headers["Accept"] then
		add_header(headers, "Accept", "*/*")
	end

	if not body then
		encode_headers(buf, headers)
		return
	end

	add_header(headers, "Content-Length", tostring(#body))
	encode_headers(buf, headers)
	buf:push(body)
end


function encode_response(buf, status, headers, body)
	buf:push(tostring(status))

	if not headers then headers = {} end
	if not headers["Date"] then headers["Date"] = httpdate() end

	if status:no_content() then
		encode_headers(buf, headers)
		return
	end

	if type(body) == "string" then
		headers["Content-Length"] = tostring(#body)
		encode_headers(buf, headers)
		buf:push(body)
		return
	end

	if body then
		headers["Content-Length"] = tostring(tonumber(body))
		encode_headers(buf, headers)
		return
	end

	headers["Transfer-Encoding"] = "chunked"
	-- do not add the closing CRLF to headers. It will be added when
	-- the first `encode_chunk` is called
	encode_headers(buf, headers, true)
end


function encode_chunk(buf, chunk)
	buf:push(CRLF)
	if not chunk then buf:push("0"..CRLF..CRLF) return end

	if type(chunk) ~= "string" then
		-- always end with CRLF when it's a number since the only option is for
		-- the user to push data to the buffer
		buf:push(num2hex(tonumber(chunk))..CRLF)
		return
	end

	buf:push(num2hex(#chunk)..CRLF..chunk)
end


function decode_request(parser, stream)
	parser:init_request()

	local err, value = parser:stream_next(stream)
	if err then return err end

	local req = setmetatable({
		method=value[1],
		path=value[2],
		headers=Map()}, Request_mt)

	repeat
		err, value = parser:stream_next(stream)
		if err then return err end
		local key = value[1]
		if not key then break end
		req.headers:add(key, value[2])
	until parser.type ~= C.SP_HTTP_FIELD

	if not value[2] then
		-- content-length request
		local len = tonumber(value[3])
		-- TODO what happens when there's no body and no chunks?
		if len > 0 then req.len = len end
	end
	-- chunked requests do not set `len`
	return nil, req
end


return {
	Status=Status,
	Parser=Parser,
	encode_request=encode_request,
	encode_response=encode_response,
	encode_chunk=encode_chunk,
	decode_request=decode_request,
}
