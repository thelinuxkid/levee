local ffi = require('ffi')
local C = ffi.C
local meta = require("levee.meta")
local encoder = require("levee.p.utf8").Utf8
local status = require("levee.p.http.status")


local VERSION = "HTTP/1.1"
local FIELD_SEP = ": "
local CRLF = "\r\n"

local USER_AGENT = ("%s/%s"):format(meta.name, meta.version.string)


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
	local e =  encoder()
	local flag = bit.bor(C.SP_UTF8_URI, C.SP_UTF8_SPACE_PLUS)
	local err, n = e:encode(value, #value, flag)
	if err then return err end
	return nil, ffi.string(e.buf, n)
end


local function encode_headers(headers, buf, nosep)
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


function encode_request(method, path, params, headers, body, buf)
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

	if not headers then headers = {} end
	-- TODO: Host
	if not headers["User-Agent"] then headers["User-Agent"] = USER_AGENT end
	if not headers["Accept"] then headers["Accept"] = "*/*" end

	if not body then
		encode_headers(headers, buf)
		return
	end

	headers["Content-Length"] = tostring(#body)
	encode_headers(headers, buf)
	buf:push(body)
end


function encode_response(status, headers, body, buf)
	buf:push(tostring(status))

	if not headers then headers = {} end
	if not headers["Date"] then headers["Date"] = httpdate() end

	if status:no_content() then
		encode_headers(headers, buf)
		return
	end

	if type(body) == "string" then
		headers["Content-Length"] = tostring(#body)
		encode_headers(headers, buf)
		buf:push(body)
		return
	end

	if body then
		headers["Content-Length"] = tostring(tonumber(body))
		encode_headers(headers, buf)
		return
	end

	headers["Transfer-Encoding"] = "chunked"
	-- do not add the closing CRLF to headers. It will be added when
	-- the first `encode_chunk` is called
	encode_headers(headers, buf, true)
end


function encode_chunk(chunk, buf)
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


return {
	Status=status,
	encode_request=encode_request,
	encode_response=encode_response,
	encode_chunk=encode_chunk,
}
