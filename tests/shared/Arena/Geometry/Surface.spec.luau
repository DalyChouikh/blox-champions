--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Centerline = require(ReplicatedStorage.Shared.Arena.Geometry.Centerline)
local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local Profile = require(ReplicatedStorage.Shared.Arena.Geometry.Profile)
local Surface = require(ReplicatedStorage.Shared.Arena.Geometry.Surface)
local Types = require(ReplicatedStorage.Shared.Arena.Geometry.Types)

describe("Surface.quadPieces", function()
	it("makes one block for a flat rectangle, with its slab behind the surface", function()
		local pieces =
			Surface.quadPieces(Vector3.zero, Vector3.new(0, 0, -4), Vector3.new(5, 0, 0), Vector3.new(5, 0, -4), 1)
		expect(#pieces).toBe(1)
		expect(pieces[1].shape).toBe("Block")
		Fixtures.expectNear(pieces[1].cframe.Position, Vector3.new(2.5, -0.5, -2))
		expect(pieces[1].cframe.UpVector.Y).toBeCloseTo(1, 4)
		Fixtures.expectNear(pieces[1].size, Vector3.new(5, 1, 4))
	end)

	it("still makes one block for a rectangle that float error leaves slightly imperfect", function()
		local noise = 2e-4
		local pieces = Surface.quadPieces(
			Vector3.new(100, 0, 100),
			Vector3.new(100 + noise, 0, 96),
			Vector3.new(105, noise, 100),
			Vector3.new(105, 0, 96 - noise),
			1
		)
		expect(#pieces).toBe(1)
		expect(pieces[1].shape).toBe("Block")
	end)

	it("splits any other quad into four wedges", function()
		local pieces =
			Surface.quadPieces(Vector3.zero, Vector3.new(0, 0, -4), Vector3.new(5, 0, 0), Vector3.new(6, 1, -4), 1)
		expect(#pieces).toBe(4)
		for _, piece in pieces do
			expect(piece.shape).toBe("Wedge")
		end
	end)
end)

describe("Surface.section", function()
	-- The sweep places it at every station; the goal's fit check and the gate panels read it at a gate.
	it("gives the solid section at a distance, blended by how straight the track is there", function()
		local arena = Config.defaults().Arena
		local function expectSection(distance: number, straightness: number)
			local expected = Profile.points(arena, straightness)
			local section = Surface.section(arena, distance)
			expect(#section).toBe(#expected)
			for index, point in expected do
				expect((section[index] - point).Magnitude).toBeLessThan(1e-4)
			end
		end
		-- A straight's section along a straight, a curved end's at its apex, and halfway at a gate (a corner).
		expectSection(arena.straightLength / 2, 1)
		expectSection(arena.straightLength + math.pi * arena.endRadius / 2, 0)
		expectSection(Centerline.gateDistance(arena, 2), 0.5)
	end)
end)

describe("Surface.build", function()
	it("sweeps the profile around the whole loop: blocks on flat rectangles, wedges everywhere else", function()
		local blocks, wedges = 0, 0
		for _, piece in Surface.build(Config.defaults().Arena) do
			if piece.shape == "Block" then
				blocks += 1
			elseif piece.shape == "Wedge" then
				wedges += 1
			end
		end
		-- 196 station steps (50 along each straight, 48 around each end) by 20 strips. No strip but the wall's is a
		-- rectangle around an end, and none is in the 20-stud blends (3 steps either side of each corner), so: each
		-- straight's 44 steps between the blends make one block per strip (40), each end's 42 steps past the blends one
		-- block for the wall (84), and the other quads four wedges each: (2 · 42 · 19 + 24 · 20) · 4 = 8304.
		expect(blocks).toBe(124)
		expect(wedges).toBe(8304)
	end)

	-- Fewer parts, and no seams across a straight for a rolling ball to bump on.
	it("spans each straight with one block per strip wherever the cross-section does not change", function()
		local arena = Config.defaults().Arena
		local whole, between = 0, 0
		local room: Types.Piece? = nil
		for _, piece in Surface.build(arena) do
			if piece.shape == "Block" then
				if math.abs(piece.size.Z - 200) < 1e-3 then
					whole += 1
				elseif math.abs(piece.size.Z - 176) < 1e-3 then
					between += 1
					if (piece.cframe.Position - Vector3.new(0, -0.5, -47)).Magnitude < 1e-3 then
						room = piece
					end
				end
			end
		end
		-- A straight's section and a curved end's share only the bank's top and the wall's top, so every strip changes
		-- in the 20-stud blend at each corner and runs 176 studs, between the first and last stations past the blends
		-- (12 and 188). The spawn room runs from the bank's foot (24) to 30: 6 wide, its middle 20 + 27 = 47 from the
		-- long axis.
		expect(whole).toBe(0)
		expect(between).toBe(2 * 20)
		expect(room).never.toBeNil()
		expect(((room :: Types.Piece).size - Vector3.new(6, 1, 176)).Magnitude).toBeLessThan(1e-3)
	end)
end)
