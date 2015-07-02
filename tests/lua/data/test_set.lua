local Set = require("levee.set")

return {
	test_membership = function()
		local s = Set("test", "other", "thing"):freeze()
		assert(s:has("test"))
		assert(s:has("other"))
		assert(s:has("thing"))
		assert(not s:has("stuff"))
	end,


	test_freeze = function()
		local s = Set("test", "other"):freeze()
		assert.error(function()
			s:put("thing")
		end)
	end,

	test_union = function()
		local s = Set("test", "other", "thing")
		local o = Set("other", "stuff")
		local copy = s + o
		s:union(o)
		assert.equal(4, #s)
		assert(s:has("test"))
		assert(s:has("other"))
		assert(s:has("thing"))
		assert(s:has("stuff"))
		assert.equals(s, Set("test", "other", "thing", "stuff"))
		assert.equals(s, copy)
	end,

	test_intersect = function()
		local s = Set("test", "other", "thing")
		local o = Set("other", "stuff")
		local copy = s / o
		s:intersect(o)
		assert.equal(1, #s)
		assert(not s:has("test"))
		assert(s:has("other"))
		assert(not s:has("thing"))
		assert(not s:has("stuff"))
		assert.equals(s, Set("other"))
		assert.equals(s, copy)
	end,

	test_diff = function()
		local s = Set("test", "other", "thing")
		local o = Set("other", "stuff")
		local copy = s - o
		s:diff(o)
		assert.equal(2, #s)
		assert(s:has("test"))
		assert(not s:has("other"))
		assert(s:has("thing"))
		assert(not s:has("stuff"))
		assert.equals(s, Set("test", "thing"))
		assert.equals(s, copy)
	end,
}
