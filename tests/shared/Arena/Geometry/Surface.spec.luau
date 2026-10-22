--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Config = require(ReplicatedStorage.Shared.Config)
local Surface = require(ReplicatedStorage.Shared.Arena.Geometry.Surface)
local Types = require(ReplicatedStorage.Shared.Arena.Geometry.Types)

local function near(actual: Vector3, expected: Vector3)
	expect((actual - expected).Magnitude).toBeLessThan(1e-3)
end

describe("Surface.quadPieces", function()
	it("makes one block for a flat rectangle, with its slab behind the surface", function()
		local pieces =
			Surface.quadPieces(Vector3.zero, Vector3.new(0, 0, -4), Vector3.new(5, 0, 0), Vector3.new(5, 0, -4), 1)
		expect(#pieces).toBe(1)
		expect(pieces[1].shape).toBe("Block")
		near(pieces[1].cframe.Position, Vector3.new(2.5, -0.5, -2))
		expect(pieces[1].cframe.UpVector.Y).toBeCloseTo(1, 4)
		near(pieces[1].size, Vector3.new(5, 1, 4))
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
		for _, piece in Surface.build(Config.defaults().Arena).surface do
			if piece.shape == "Block" then
				blocks += 1
			elseif piece.shape == "Wedge" then
				wedges += 1
			end
		end
		-- Measured, not derived: the walls and floors only (A2 moved the roof to Surface.build's roof list). The
		-- straights keep one block per constant strip; the curves' wedges follow their strip counts.
		expect(blocks).toBe(230)
		expect(wedges).toBe(7104)
	end)

	-- Fewer parts, and no seams across a straight for a rolling ball to bump on.
	it("spans each straight with one block per strip wherever the cross-section does not change", function()
		local arena = Config.defaults().Arena
		local whole, between = 0, 0
		local lowerFloor: Types.Piece? = nil
		for _, piece in Surface.build(arena).surface do
			if piece.shape == "Block" then
				if math.abs(piece.size.Z - 160) < 1e-3 then
					whole += 1
					if (piece.cframe.Position - Vector3.new(0, -0.5, -53)).Magnitude < 1e-3 then
						lowerFloor = piece
					end
				elseif math.abs(piece.size.Z - 136) < 1e-3 then
					between += 1
				end
			end
		end
		expect(whole).toBe(2 * 7)
		-- The outer foot has six strips now (A2), one more constant strip than before, on each straight.
		expect(between).toBe(2 * 12)
		expect(lowerFloor).never.toBeNil()
		expect(((lowerFloor :: Types.Piece).size - Vector3.new(10, 1, 160)).Magnitude).toBeLessThan(1e-3)
	end)
end)
