--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local Profile = require(ReplicatedStorage.Shared.Arena.Geometry.Profile)

local arena = Config.defaults().Arena
local near = Fixtures.expectNear2

-- The defaults' cross-sections (#268, the owner's pick: trial 6; Arena spec §3.1), worked out independently of the
-- code. On a straight: the bank a quarter ellipse (0, 16) → (24, 0), the spawn room to 30, the rise to (44, 8) arriving
-- at tan 14°, the incline to (63.322, 12.818), the foot curve r 22 to (80, 34.164) and the wall to 40. At a curved end:
-- the bank a quarter circle to (16, 0), the bowl y = 14 s² to (70.255, 14), arriving at 27.297°, the foot curve r 18
-- from there to (80, 29.996) and the wall to 40.
describe("Profile", function()
	local straight = Profile.points(arena, 1)
	local curvedEnd = Profile.points(arena, 0)

	it("gives every piece a strip and shares the rest by how far each piece turns where it turns more", function()
		-- 14 spare strips by turning, over 64 chords a piece: the bank 88.59° (a quarter turn), the room 4.43° (the
		-- curved ends' bowl), the rise 61.04° (the straights' S), the incline 12.39° (the bowl), the foot curve 74.81°
		-- (the straights' r 22 from 14°) and the wall 0, of 241.27°, give 5.14, 0.26, 3.54, 0.72, 4.34 and 0: 5, 0, 3,
		-- 0, 4 and 0, and the two left over to the largest remainders, the incline's and the rise's.
		expect(Profile.stripCounts(arena)).toEqual({ 6, 1, 5, 2, 5, 1 })
	end)

	it("runs a straight's section from the bank's top down, across the room, up the rise and the incline", function()
		expect(#straight).toBe(21)
		local expected = {
			[1] = Vector2.new(0, 16),
			[7] = Vector2.new(24, 0),
			[8] = Vector2.new(30, 0),
			[13] = Vector2.new(44, 8),
			[14] = Vector2.new(53.6611, 10.4088),
			[15] = Vector2.new(63.3223, 12.8176),
			[20] = Vector2.new(80, 34.1641),
			[21] = Vector2.new(80, 40),
		}
		for index, point in expected do
			near(straight[index], point)
		end
		-- The spawn room's middle: (24 + 30) / 2.
		expect(Profile.spawnLane(arena)).toBe(27)
	end)

	-- Both leave the glass vertically and meet the floor flat, and the foot curve leaves the incline along it: one
	-- smooth surface from the inner glass to the outer one.
	it(
		"rounds a straight's bank as a quarter ellipse and its foot as a circle that leaves the incline along it",
		function()
			for index = 1, 7 do
				local onBank = (straight[index] - Vector2.new(24, 16)) / Vector2.new(24, 16)
				expect(onBank.Magnitude).toBeCloseTo(1, 3)
			end
			for index = 15, 20 do
				expect((straight[index] - Vector2.new(58, 34.1641)).Magnitude).toBeCloseTo(22, 3)
			end
			local incline = straight[15] - straight[13]
			expect(math.deg(math.atan2(incline.Y, incline.X))).toBeCloseTo(14, 3)
		end
	)

	it("rises from the room's flat floor onto the incline in one smooth S", function()
		-- Five strips across 30 to 44, on y = (3 − 2t) t² · 8 + (t − 1) t² · 14 tan 14°.
		near(straight[9], Vector2.new(32.8, 0.7203))
		near(straight[10], Vector2.new(35.6, 2.4809))
		near(straight[11], Vector2.new(38.4, 4.6814))
		near(straight[12], Vector2.new(41.2, 6.7212))
	end)

	it("bowls a curved end's floor up from the bank's foot to the foot curve, steeper toward the wall", function()
		expect(#curvedEnd).toBe(21)
		near(curvedEnd[1], Vector2.new(0, 16))
		for index = 1, 7 do
			expect((curvedEnd[index] - Vector2.new(16, 16)).Magnitude).toBeCloseTo(16, 3)
		end
		near(curvedEnd[7], Vector2.new(16, 0))
		-- Split where the straights' room and rise end, by their shares of its floor (6 and 20 of 39.32): 0.153 and
		-- 0.509 of the way across, 0.326 and 3.622 high.
		near(curvedEnd[8], Vector2.new(24.2785, 0.326))
		near(curvedEnd[13], Vector2.new(43.595, 3.6217))
		near(curvedEnd[15], Vector2.new(70.255, 14))
		for index = 8, 15 do
			local share = (curvedEnd[index].X - 16) / 54.255
			expect(curvedEnd[index].Y).toBeCloseTo(14 * share * share, 3)
		end
		for index = 15, 20 do
			expect((curvedEnd[index] - Vector2.new(62, 29.9955)).Magnitude).toBeCloseTo(18, 3)
		end
		near(curvedEnd[20], Vector2.new(80, 29.9955))
		near(curvedEnd[21], Vector2.new(80, 40))
	end)

	it("blends a curved end's section into a straight's point by point", function()
		local corner = Profile.points(arena, 0.5)
		expect(#corner).toBe(21)
		near(corner[7], Vector2.new(20, 0))
		near(corner[8], Vector2.new(27.1393, 0.163))
		near(corner[13], Vector2.new(43.7975, 5.8108))
		near(corner[15], Vector2.new(66.7886, 13.4088))
		near(corner[20], Vector2.new(80, 32.0798))
	end)

	-- Each glass section runs the profile's way (down the inner side, up the outer one), its lip a quarter circle of
	-- radius 12 in four strips, evenly spaced by angle, from vertical at 108 to horizontal at 120 (R15).
	it("curls each glass wall into a lip at the top, ending where the top begins", function()
		local outer = Profile.outerGlass(arena)
		local expected = {
			Vector2.new(80, 40),
			Vector2.new(80, 108),
			Vector2.new(79.087, 112.592),
			Vector2.new(76.485, 116.485),
			Vector2.new(72.592, 119.087),
			Vector2.new(68, 120),
		}
		expect(#outer).toBe(#expected)
		for index, point in expected do
			near(outer[index], point)
		end
		-- The inner glass mirrors it across the track, from the lip's end down to the bank's top.
		local inner = Profile.innerGlass(arena)
		expect(#inner).toBe(#expected)
		for index, point in expected do
			local mirrored = Vector2.new(arena.trackWidth - point.X, point.Y)
			near(inner[#expected + 1 - index], if index == 1 then Vector2.new(0, 16) else mirrored)
		end
	end)

	-- A gate panel ends at this outline, so it meets the lips as built (their chords) and never pokes through them.
	it("follows the walls' top as built across the track: the lips' chords, and glass.top between them", function()
		local outline = Profile.topOutline(arena)
		-- From the inner glass's face to the outer one, always toward the outer glass: a height at every u between.
		near(outline[1], Vector2.new(0, 108))
		near(outline[#outline], Vector2.new(80, 108))
		for index = 2, #outline do
			expect(outline[index].X > outline[index - 1].X).toBe(true)
		end
		local cases = { { 0, 108 }, { 80, 108 }, { 12, 120 }, { 40, 120 }, { 68, 120 }, { 76.485, 116.485 } }
		for _, case in cases do
			expect(Profile.heightAt(outline, case[1])).toBeCloseTo(case[2], 3)
		end
		-- On the chord from (3.515, 116.485) to (7.408, 119.087), not on the lip's circle.
		local t = (6 - 3.515) / (7.408 - 3.515)
		expect(Profile.heightAt(outline, 6)).toBeCloseTo(116.485 + t * (119.087 - 116.485), 2)
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
