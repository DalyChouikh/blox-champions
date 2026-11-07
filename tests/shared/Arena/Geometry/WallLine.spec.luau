--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Centerline = require(ReplicatedStorage.Shared.Arena.Geometry.Centerline)
local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local WallLine = require(ReplicatedStorage.Shared.Arena.Geometry.WallLine)

local arena = Config.defaults().Arena
local LIFT = 0.45

-- The defaults' loop (Arena spec §3.1): the top straight (gate 1) runs from x 130 to -130 at z -60 heading -X, 260
-- long in 65 chords 4 apart; the left curved end (gate 2) is a half circle round (-130, 0), 188.5 long in 48 chords.
-- A straight's section is a straight's from 10 in from each end (profileBlendLength 20 centred on its corners). The
-- outer wall's glass line (20) on a straight lies 74.8338 across from the inner glass's face, its normal toward the
-- track (-0.76516, 0.64382) (Profile's worked values): lifted 0.45 along it, 74.4895 across (z -60 - 34.4895) and
-- 20.2897 up.
describe("WallLine", function()
	it("runs a line along each section from its gate to the next, piece after piece", function()
		for gate = 1, Centerline.gateCount do
			local pieces = WallLine.section(arena, gate, 20, LIFT)
			local finish = if gate < Centerline.gateCount
				then Centerline.gateDistance(arena, gate + 1)
				else Centerline.length(arena)
			expect(pieces[1].from).toBeCloseTo(Centerline.gateDistance(arena, gate), 4)
			expect(pieces[#pieces].to).toBeCloseTo(finish, 4)
			for index = 2, #pieces do
				expect(pieces[index].from).toBe(pieces[index - 1].to)
				Fixtures.expectNear(pieces[index].start, pieces[index - 1].finish)
			end
		end
	end)

	it("rests the line on the outer wall at its height, lifted off it along its normal", function()
		-- The straight's middle, where its section is a straight's: one piece from 12 to 248 along the track.
		local middle = WallLine.section(arena, 1, 20, LIFT)[4]
		expect(middle.from).toBeCloseTo(12, 4)
		expect(middle.to).toBeCloseTo(248, 4)
		Fixtures.expectNear(middle.start, Vector3.new(118, 20.2897, -94.4895), 1e-3)
		Fixtures.expectNear(middle.finish, Vector3.new(-118, 20.2897, -94.4895), 1e-3)
	end)

	it("joins the chords that keep one direction into one piece, and keeps a curve's apart", function()
		-- A straight: three chords at each end, where its section blends into a curved end's, and its middle.
		expect(#WallLine.section(arena, 1, 20, LIFT)).toBe(7)
		-- A curved end: each of its 48 chords turns.
		expect(#WallLine.section(arena, 2, 20, LIFT)).toBe(48)
		-- On the upright glass the line never moves across the track: a straight is one piece, its blends too.
		local upright = WallLine.section(arena, 1, 60, LIFT)
		expect(#upright).toBe(1)
		Fixtures.expectNear(upright[1].start, Vector3.new(130, 60, -99.55), 1e-3)
		Fixtures.expectNear(upright[1].finish, Vector3.new(-130, 60, -99.55), 1e-3)
	end)
end)
