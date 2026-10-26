--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
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
		-- strip counts.
		expect(blocks).toBe(136)
		expect(wedges).toBe(8016)
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
					if (piece.cframe.Position - Vector3.new(0, -0.5, -42)).Magnitude < 1e-3 then
						lowerFloor = piece
					end
				elseif math.abs(piece.size.Z - 176) < 1e-3 then
					between += 1
				end
			end
		end
		-- The bank's four strips and the lower floor never change along a straight. The step's five, the upper
		-- floor, the foot curve's eight and the outer wall change in the 20-stud blend at each corner, so they run
		-- 176 studs, between the first and last stations past the blends (12 and 188).
		expect(whole).toBe(2 * 5)
		expect(between).toBe(2 * 15)
		expect(lowerFloor).never.toBeNil()
		expect(((lowerFloor :: Types.Piece).size - Vector3.new(28, 1, 200)).Magnitude).toBeLessThan(1e-3)
	end)
end)
