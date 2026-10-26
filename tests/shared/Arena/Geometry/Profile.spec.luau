--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local Profile = require(ReplicatedStorage.Shared.Arena.Geometry.Profile)

local arena = Config.defaults().Arena

local function near(actual: Vector2, expected: Vector2, tolerance: number?)
	expect((actual - expected).Magnitude).toBeLessThan(tolerance or 1e-4)
end

-- The defaults' cross-section on a straight (Arena spec §3.1): the bank (0, 8) → (8, 0), the lower floor to 36, the
-- step to (54, 4), the upper floor to 62, the foot curve to (80, 22) and the outer wall to (80, 28).
describe("Profile", function()
	it(
		"gives each floor and the wall one strip and shares the rest across the bank, the step and the foot curve",
		function()
			expect(Profile.stripCounts(arena)).toEqual({ 4, 1, 5, 1, 8, 1 })
		end
	)

	it("ends at the outer wall's top, where the glass stands on it", function()
		local p = Profile.points(arena, arena.stepHeight)
		expect(#p).toBe(21)
		near(p[#p], Vector2.new(arena.trackWidth, arena.outerWallHeight))
	end)

	it("runs from the inner bank's top down, across the floors and the step, and up the outer wall", function()
		local p = Profile.points(arena, 4)
		near(p[1], Vector2.new(0, 8))
		near(p[5], Vector2.new(8, 0))
		near(p[6], Vector2.new(36, 0))
		near(p[11], Vector2.new(54, 4))
		near(p[12], Vector2.new(62, 4))
		near(p[20], Vector2.new(80, 22))
		near(p[21], Vector2.new(80, 28))
		expect(Profile.lowerFloorCenter(arena)).toBe(22)
	end)

	it("rounds the inner bank with innerBankHeight and the outer wall's foot with wallCurveRadius", function()
		local p = Profile.points(arena, 4)
		for index = 1, 5 do
			expect((p[index] - Vector2.new(8, 8)).Magnitude).toBeCloseTo(8, 3)
		end
		for index = 12, 20 do
			expect((p[index] - Vector2.new(62, 22)).Magnitude).toBeCloseTo(18, 3)
		end
	end)

	it("shapes the step as one smooth rise from the lower to the upper floor", function()
		local p = Profile.points(arena, 4)
		-- Five strips: points at t = 0.4 and 0.8 of the way across, on 2 · (1 − cos(π t)).
		expect(p[8].Y).toBeCloseTo(2 - 2 * math.cos(0.4 * math.pi), 3)
		expect(p[10].Y).toBeCloseTo(2 - 2 * math.cos(0.8 * math.pi), 3)
	end)

	it("keeps the same points with no step, so straights and curves blend point by point", function()
		local flat = Profile.points(arena, 0)
		expect(#flat).toBe(21)
		for index = 5, 12 do
			expect(flat[index].Y).toBeCloseTo(0, 4)
		end
		near(flat[20], Vector2.new(80, 18))
	end)

	-- Each glass section runs the profile's way (down the inner side, up the outer one), its lip a quarter circle of
	-- radius 12 in four strips, evenly spaced by angle, from vertical at 108 to horizontal at 120 (R15).
	it("curls each glass wall into a lip at the top, ending where the top begins", function()
		local outer = Profile.outerGlass(arena)
		local expected = {
			Vector2.new(80, 28),
			Vector2.new(80, 108),
			Vector2.new(79.087, 112.592),
			Vector2.new(76.485, 116.485),
			Vector2.new(72.592, 119.087),
			Vector2.new(68, 120),
		}
		expect(#outer).toBe(#expected)
		for index, point in expected do
			near(outer[index], point, 1e-3)
		end
		-- The inner glass mirrors it across the track, from the lip's end down to the bank's top.
		local inner = Profile.innerGlass(arena)
		expect(#inner).toBe(#expected)
		for index, point in expected do
			local mirrored = Vector2.new(arena.trackWidth - point.X, point.Y)
			near(inner[#expected + 1 - index], if index == 1 then Vector2.new(0, 8) else mirrored, 1e-3)
		end
	end)

	-- The top closes the track's "O": it runs on from the outer lip's end back to the inner one's (Arena spec §3.1,
	-- R14).
	it("closes the top across the track at the walls' top, or above it with an open map's ceiling", function()
		local closed = Profile.top(arena)
		expect(#closed).toBe(2)
		near(closed[1], Vector2.new(68, 120))
		near(closed[2], Vector2.new(12, 120))
		expect(Profile.topHeight(arena)).toBe(120)

		local open = Fixtures.config({ Arena = { top = { kind = "Open" } } }).Arena
		local section = Profile.top(open)
		expect(#section).toBe(4)
		near(section[1], Vector2.new(68, 120))
		near(section[2], Vector2.new(68, 140))
		near(section[3], Vector2.new(12, 140))
		near(section[4], Vector2.new(12, 120))
		expect(Profile.topHeight(open)).toBe(140)
	end)
end)
