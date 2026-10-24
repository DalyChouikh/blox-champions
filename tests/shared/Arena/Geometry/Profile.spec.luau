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
	it(
		"gives each wall and floor one strip and shares the rest across the curves, the step and the roof by length",
		function()
			expect(Profile.stripCounts(arena)).toEqual({ 1, 5, 1, 4, 1, 6, 1, 21 })
		end
	)

	it("closes the tube: a roof arc runs from the outer wall top over to the inner wall top", function()
		local p = Profile.points(arena, arena.stepHeight)
		near(p[#p], p[1])
		-- The arc's centre is the midpoint of the two tops, and its radius half their distance: 22 studs, apex 50.
		expect(Profile.roofTop(arena)).toBeCloseTo(50, 6)
		local apex = 0
		for _, point in p do
			apex = math.max(apex, point.Y)
		end
		-- 21 strips over the roof put no sample exactly at the top: the nearest is about 0.06 studs under it.
		expect(apex).toBeGreaterThan(49.9)
		expect(apex).toBeLessThan(50.001)
	end)

	it("gives the roof's circle: centred between the wall tops, its radius half their distance", function()
		local center, radius = Profile.roofCircle(arena)
		near(center, Vector2.new(22, 28))
		expect(radius).toBeCloseTo(22, 6)
		local uneven = table.clone(arena)
		uneven.outerWallHeight = 32
		center, radius = Profile.roofCircle(uneven)
		near(center, Vector2.new(22, 30))
		-- Vector2 holds single-precision numbers.
		expect(radius).toBeCloseTo(math.sqrt(44 * 44 + 4 * 4) / 2, 4)
	end)

	it("puts the roof's first point at the outer wall top, where the outer wall ends", function()
		local counts = Profile.stripCounts(arena)
		local roofStart = Profile.roofEdge(arena)
		local outerWallTop = Profile.points(arena, arena.stepHeight)[roofStart]
		near(outerWallTop, Vector2.new(arena.trackWidth, arena.outerWallHeight))
		expect(roofStart).toBe(1 + counts[1] + counts[2] + counts[3] + counts[4] + counts[5] + counts[6] + counts[7])
	end)

	it("runs from the inner wall top down, across the floors and the step, and up the outer wall", function()
		local p = Profile.points(arena, 4)
		expect(#p).toBe(41)
		near(p[1], Vector2.new(0, 28))
		near(p[2], Vector2.new(0, 10))
		near(p[7], Vector2.new(10, 0))
		near(p[8], Vector2.new(20, 0))
		near(p[10], Vector2.new(25, 2))
		near(p[12], Vector2.new(30, 4))
		near(p[13], Vector2.new(34, 4))
		near(p[19], Vector2.new(44, 14))
		near(p[20], Vector2.new(44, 28))
		expect(Profile.lowerFloorCenter(arena)).toBe(15)
	end)

	it("rounds each wall foot with wallCurveRadius", function()
		local p = Profile.points(arena, 4)
		for index = 2, 7 do
			expect((p[index] - Vector2.new(10, 10)).Magnitude).toBeCloseTo(10, 3)
		end
		for index = 13, 19 do
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
		expect(#flat).toBe(41)
		for index = 7, 13 do
			expect(flat[index].Y).toBeCloseTo(0, 4)
		end
		near(flat[19], Vector2.new(44, 10))
	end)
end)
