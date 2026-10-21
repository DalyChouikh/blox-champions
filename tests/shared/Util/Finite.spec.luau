--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Finite = require(ReplicatedStorage.Shared.Util.Finite)

describe("Finite", function()
	it("accepts ordinary numbers and rejects NaN and both infinities", function()
		expect(Finite.number(0)).toBe(true)
		expect(Finite.number(-1e300)).toBe(true)
		expect(Finite.number(0 / 0)).toBe(false)
		expect(Finite.number(math.huge)).toBe(false)
		expect(Finite.number(-math.huge)).toBe(false)
	end)

	it("checks every component of a vector", function()
		expect(Finite.vector(Vector3.new(1, -2, 3))).toBe(true)
		expect(Finite.vector(Vector3.new(0 / 0, 0, 0))).toBe(false)
		expect(Finite.vector(Vector3.new(0, -math.huge, 0))).toBe(false)
		expect(Finite.vector(Vector3.new(0, 0, math.huge))).toBe(false)
	end)
end)
