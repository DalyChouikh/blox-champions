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

-- The defaults' cross-section on a straight (Arena spec §3.1): the bank (0, 8) → (8, 0), the lower floor to 26, the
-- step to (40, 4), the upper floor to 46, the foot curve to (60, 18) and the outer wall to (60, 28).
describe("Profile", function()
	it(
		"gives each floor and the wall one strip and shares the rest across the bank, the step and the foot curve",
		function()
			expect(Profile.stripCounts(arena)).toEqual({ 5, 1, 5, 1, 7, 1 })
		end
	)

	it("ends at the outer wall's top: no roof", function()
		local p = Profile.points(arena, arena.stepHeight)
		expect(#p).toBe(21)
		near(p[#p], Vector2.new(arena.trackWidth, arena.outerWallHeight))
	end)

	it("runs from the inner bank's top down, across the floors and the step, and up the outer wall", function()
		local p = Profile.points(arena, 4)
		near(p[1], Vector2.new(0, 8))
		near(p[6], Vector2.new(8, 0))
		near(p[7], Vector2.new(26, 0))
		near(p[12], Vector2.new(40, 4))
		near(p[13], Vector2.new(46, 4))
		near(p[20], Vector2.new(60, 18))
		near(p[21], Vector2.new(60, 28))
		expect(Profile.lowerFloorCenter(arena)).toBe(17)
	end)

	it("rounds the inner bank with innerBankHeight and the outer wall's foot with wallCurveRadius", function()
		local p = Profile.points(arena, 4)
		for index = 1, 6 do
			expect((p[index] - Vector2.new(8, 8)).Magnitude).toBeCloseTo(8, 3)
		end
		for index = 13, 20 do
			expect((p[index] - Vector2.new(46, 18)).Magnitude).toBeCloseTo(14, 3)
		end
	end)

	it("shapes the step as one smooth rise from the lower to the upper floor", function()
		local p = Profile.points(arena, 4)
		-- Five strips: points at t = 0.4 and 0.8 of the way across, on 2 · (1 − cos(π t)).
		expect(p[9].Y).toBeCloseTo(2 - 2 * math.cos(0.4 * math.pi), 3)
		expect(p[11].Y).toBeCloseTo(2 - 2 * math.cos(0.8 * math.pi), 3)
	end)

	it("keeps the same points with no step, so straights and curves blend point by point", function()
		local flat = Profile.points(arena, 0)
		expect(#flat).toBe(21)
		for index = 6, 13 do
			expect(flat[index].Y).toBeCloseTo(0, 4)
		end
		near(flat[20], Vector2.new(60, 14))
	end)
end)
