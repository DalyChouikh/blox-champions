--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Config = require(ReplicatedStorage.Shared.Config)
local Profile = require(ReplicatedStorage.Shared.Arena.Geometry.Profile)

local arena = Config.defaults().Arena

local function near(actual: Vector2, expected: Vector2)
	expect((actual - expected).Magnitude).toBeLessThan(1e-4)
end

describe("Profile", function()
	it("gives each wall and floor one strip and shares the rest across the curves and the step by length", function()
		expect(Profile.stripCounts(arena)).toEqual({ 1, 5, 1, 4, 1, 5, 1 })
	end)

	it("runs from the inner wall top down, across the floors and the step, and up the outer wall", function()
		local p = Profile.points(arena, 4)
		expect(#p).toBe(19)
		near(p[1], Vector2.new(0, 20))
		near(p[2], Vector2.new(0, 10))
		near(p[7], Vector2.new(10, 0))
		near(p[8], Vector2.new(20, 0))
		near(p[10], Vector2.new(25, 2))
		near(p[12], Vector2.new(30, 4))
		near(p[13], Vector2.new(34, 4))
		near(p[18], Vector2.new(44, 14))
		near(p[19], Vector2.new(44, 28))
		expect(Profile.lowerFloorCenter(arena)).toBe(15)
	end)

	it("rounds each wall foot with wallCurveRadius", function()
		local p = Profile.points(arena, 4)
		for index = 2, 7 do
			expect((p[index] - Vector2.new(10, 10)).Magnitude).toBeCloseTo(10, 3)
		end
		for index = 13, 18 do
			expect((p[index] - Vector2.new(34, 14)).Magnitude).toBeCloseTo(10, 3)
		end
	end)

	it("shapes the step as one smooth rise from the lower to the upper floor", function()
		local p = Profile.points(arena, 4)
		expect(p[9].Y).toBeCloseTo(2 - math.sqrt(2), 3)
		expect(p[11].Y).toBeCloseTo(2 + math.sqrt(2), 3)
	end)

	it("keeps the same points with no step, so straights and curves blend point by point", function()
		local flat = Profile.points(arena, 0)
		expect(#flat).toBe(19)
		for index = 7, 13 do
			expect(flat[index].Y).toBeCloseTo(0, 4)
		end
		near(flat[18], Vector2.new(44, 10))
	end)
end)
