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
	it("gives the solid section at a distance, with the straights' step blended there", function()
		local arena = Config.defaults().Arena
		local function expectSection(distance: number, stepHeight: number)
			local expected = Profile.points(arena, stepHeight)
			local section = Surface.section(arena, distance)
			expect(#section).toBe(#expected)
			for index, point in expected do
				expect((section[index] - point).Magnitude).toBeLessThan(1e-4)
			end
		end
		-- The full step along a straight, none at a curved end's apex, and half at a gate (a corner).
		expectSection(arena.straightLength / 2, arena.stepHeight)
		expectSection(arena.straightLength + math.pi * arena.endRadius / 2, 0)
		expectSection(Centerline.gateDistance(arena, 2), arena.stepHeight / 2)
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
		-- Measured, not derived: the straights keep one block per constant strip; the curves' wedges follow their
		-- strip counts. The 16-stud bank (#217) took 96 wedges off the 8-stud one's 8016: the two strips it moved from
		-- the foot curve stopped changing in the blends, 2 quads of 4 wedges in each of the 12 blend segments.
		expect(blocks).toBe(136)
		expect(wedges).toBe(7920)
	end)

	-- Fewer parts, and no seams across a straight for a rolling ball to bump on.
	it("spans each straight with one block per strip wherever the cross-section does not change", function()
		local arena = Config.defaults().Arena
		local whole, between = 0, 0
		local lowerFloor: Types.Piece? = nil
		for _, piece in Surface.build(arena) do
			if piece.shape == "Block" then
				if math.abs(piece.size.Z - 200) < 1e-3 then
					whole += 1
					if (piece.cframe.Position - Vector3.new(0, -0.5, -46)).Magnitude < 1e-3 then
						lowerFloor = piece
					end
				elseif math.abs(piece.size.Z - 176) < 1e-3 then
					between += 1
				end
			end
		end
		-- The bank's six strips and the lower floor never change along a straight. The step's five, the upper floor,
		-- the foot curve's six and the outer wall change in the 20-stud blend at each corner, so they run 176 studs,
		-- between the first and last stations past the blends (12 and 188). The lower floor runs from the bank's
		-- foot (16) to the step (36): 20 wide, its middle 20 + 26 = 46 from the long axis.
		expect(whole).toBe(2 * 7)
		expect(between).toBe(2 * 13)
		expect(lowerFloor).never.toBeNil()
		expect(((lowerFloor :: Types.Piece).size - Vector3.new(20, 1, 200)).Magnitude).toBeLessThan(1e-3)
	end)
end)
