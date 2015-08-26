local os = require('os')

local Argv = require('levee.argv')
local cmd = require('levee.cmd')


local function usage()
	local ret = {
		"usage: levee <command> ...\n\n",
		"Available commands are:\n", }

	for k, v in pairs(cmd) do
		table.insert(ret, "\t"..k)
		table.insert(ret, "\n")
	end

	table.remove(ret)  -- pop trailing newline
	return table.concat(ret)
end


-- main

local function main()
	local name = arg[1]

	if not cmd[name] then
		if not name then
			print(usage())
		else
			print("unknown command: " .. name)
		end
		return 1
	end

	local command = cmd[name]

	if arg[2] == "-h" or arg[2] == "--help" then
		print(command.usage())
		return
	end

	local options = command.parse(Argv(arg, 2))

	if not options then
		print(command.usage())
		return 1
	end

	local ok, err = pcall(command.run, options)
	if not ok then
		print(err)
		return 1
	end
end

os.exit(main())
