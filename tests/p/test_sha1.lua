local sha1 = require('levee.p.sha1')


return {
	test_sha1 = function()
		assert.equal(sha1(("x"):rep(64)) , "bb2fa3ee7afb9f54c6dfb5d021f14b1ffe40c163")
		assert.equal(sha1("http://regex.info/blog/"), "7f103bf600de51dfe91062300c14738b32725db5")
		assert.equal(sha1(string.rep("a", 10000)), "a080cbda64850abb7b7f67ee875ba068074ff6fe")
		assert.equal(sha1("abc"), "a9993e364706816aba3e25717850c26c9cd0d89d")
		assert.equal(sha1("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"), "84983e441c3bd26ebaae4aa1f95129e5e54670f1")
		assert.equal(sha1("The quick brown fox jumps over the lazy dog"), "2fd4e1c67a2d28fced849ee1bb76e7391b93eb12")
		assert.equal(sha1("The quick brown fox jumps over the lazy cog"), "de9f2c7fd25e1b3afad3e85a0bd17d9b100db4b3")
	end,

	test_hmac = function()
		assert.equal("31285f3fa3c6a086d030cf0f06b07e7a96b5cbd0", sha1.hmac("63xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",   "data"))
		assert.equal("2d183212abc09247e21282d366eeb14d0bc41fb4", sha1.hmac("64xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",  "data"))
		assert.equal("ff825333e64e696fc13d82c19071fa46dc94a066", sha1.hmac("65xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", "data"))
	end,
}
