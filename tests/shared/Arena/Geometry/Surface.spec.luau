--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Config = require(ReplicatedStorage.Shared.Config)
local Surface = require(ReplicatedStorage.Shared.Arena.Geometry.Surface)

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

	it("splits any other quad into four wedges", function()
		local pieces =
			Surface.quadPieces(Vector3.zero, Vector3.new(0, 0, -4), Vector3.new(5, 0, 0), Vector3.new(6, 1, -4), 1)
		expect(#pieces).toBe(4)
		for _, piece in pieces do
			expect(piece.shape).toBe("Wedge")
		end
	end)
end)

describe("Surface.pieces", function()
	it("sweeps the profile around the whole loop: blocks on flat rectangles, wedges everywhere else", function()
		local blocks, wedges = 0, 0
		for _, piece in Surface.pieces(Config.defaults().Arena) do
			if piece.shape == "Block" then
				blocks += 1
			elseif piece.shape == "Wedge" then
				wedges += 1
			end
		end
		-- Straights: 34 interior stations x 18 blocks, 6 blend stations x (8 blocks + 10 x 4 wedges).
		-- Curves: 42 flat stations x (2 wall blocks + 16 x 4 wedges), 6 blend stations x (1 block + 17 x 4 wedges).
		expect(blocks).toBe(1500)
		expect(wedges).toBe(6672)
	end)
end)
