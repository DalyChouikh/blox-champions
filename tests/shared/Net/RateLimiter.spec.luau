--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local RateLimiter = require(ReplicatedStorage.Shared.Net.RateLimiter)

describe("RateLimiter", function()
	it("allows a burst of perSecond messages, then refills over time", function()
		local limiter = RateLimiter.new(4)
		for _ = 1, 4 do
			expect(limiter:allow("A", 0)).toBe(true)
		end
		expect(limiter:allow("A", 0)).toBe(false)
		expect(limiter:allow("A", 0.25)).toBe(true) -- one token back after a quarter second
		expect(limiter:allow("A", 0.25)).toBe(false)
	end)

	it("counts each player separately and forgets one who left", function()
		local limiter = RateLimiter.new(1)
		expect(limiter:allow("A", 0)).toBe(true)
		expect(limiter:allow("B", 0)).toBe(true)
		expect(limiter:allow("A", 0)).toBe(false)
		limiter:forget("A")
		expect(limiter:allow("A", 0)).toBe(true)
	end)
end)
