local ev = require("ev")

ev.run(function(h)

	local serve = h.tcp:listen(8000)

	while true do
		local conn = serve:recv()
		print("ACCEPTED", conn)

		h:spawn(function()
			for message in conn do
				print("ECHO", message)
			end
			print("ECHO DONE")
		end)
	end

end)

if false then
	ev.run(function(h)
		local p = h:pipe()

		h:spawn(function()
			print("spawn start")
			p:send("oh hai 1")
			print("spawn done")
		end)

		local got = p:recv()
		print("recv", got)

		h:spawn(function()
			print("spawn start")
			local got = p:recv()
			print("recv", got)
			print("spawn done")
		end)

		p:send("oh hai 2")

		print("out")
	end)
end


print("done")


-----


if false then
	local conn = ev.tcp.connect(8000)

	for _, str in ipairs{"hello", "goodbye"} do
		conn:send(str)
		print(conn:recv())
	end

	conn:close()
end
