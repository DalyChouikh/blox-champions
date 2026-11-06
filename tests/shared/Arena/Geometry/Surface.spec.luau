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

-- Blocks and wedges among `pieces`.
local function countShapes(pieces: { Types.Piece }): (number, number)
	local blocks, wedges = 0, 0
	for _, piece in pieces do
		if piece.shape == "Block" then
			blocks += 1
		elseif piece.shape == "Wedge" then
			wedges += 1
		end
	end
	return blocks, wedges
end

describe("Surface.sweep", function()
	-- Surface.build sweeps the strips that look solid and those that look like the glass from one set of rings.
	it("sweeps only the strips `include` lets through, each as the whole sweep does", function()
		local arena = Config.defaults().Arena
		local rings = Surface.rings(arena, function(distance: number): { Vector2 }
			return Surface.section(arena, distance)
		end)
		local whole = Surface.sweep(rings, arena.surfaceThickness)
		local swept = 0
		for strip = 1, #rings[1] - 1 do
			local alone = Surface.sweep(rings, arena.surfaceThickness, function(included: number): boolean
				return included == strip
			end)
			expect(#alone).toBeGreaterThan(0)
			for _, piece in alone do
				swept += 1
				local same = whole[swept]
				if
					same == nil
					or piece.shape ~= same.shape
					or piece.cframe ~= same.cframe
					or piece.size ~= same.size
				then
					error(`strip {strip}'s piece {swept} is not the whole sweep's`)
				end
			end
		end
		expect(swept).toBe(#whole)
	end)
end)

describe("Surface.build", function()
	it("sweeps the profile around the whole loop: blocks on flat rectangles, wedges everywhere else", function()
		local solid, glassLook = Surface.build(Config.defaults().Arena)
		local solidBlocks, solidWedges = countShapes(solid)
		local glassBlocks, glassWedges = countShapes(glassLook)
		-- 226 station steps (65 along each straight, 48 around each end) by 22 strips (Profile). No strip but the
		-- wall's is a rectangle around an end, and none is in the 20-stud blends (3 steps either side of each corner),
		-- so: each straight's 59 steps between the blends make one block per strip, however long the straights, each
		-- end's 42 steps past the blends one block for the wall, and the other quads four wedges each. The 15 strips
		-- below the glass lines: 2 · 15 = 30 blocks and (2 · 42 · 15 + 24 · 15) · 4 = 6480 wedges; the 7 that look
		-- like the glass (the bank's 3 above 6, the foot curve's 3 above 20 and the wall): 2 · 7 + 2 · 42 = 98 blocks
		-- and (2 · 42 · 6 + 24 · 7) · 4 = 2688 wedges.
		expect({ solidBlocks, solidWedges }).toEqual({ 30, 6480 })
		expect({ glassBlocks, glassWedges }).toEqual({ 98, 2688 })
	end)

	-- Q309: the look only; each edge between the two sits at its line exactly (Profile).
	it("keeps what looks like the glass above the bank's line, and what looks solid below the outer wall's", function()
		local arena = Config.defaults().Arena
		local solid, glassLook = Surface.build(arena)
		-- A slab's centre sits within its thickness of its strip.
		local slab = arena.surfaceThickness
		for index, piece in glassLook do
			if piece.cframe.Position.Y < arena.glassLook.innerBank - slab then
				error(`glass-look piece {index} is below the inner bank's line`)
			end
		end
		for index, piece in solid do
			if piece.cframe.Position.Y > arena.glassLook.outerWall + slab then
				error(`solid piece {index} is above the outer wall's line`)
			end
		end
	end)

	-- Fewer parts, and no seams across a straight for a rolling ball to bump on.
	it("spans each straight with one block per strip wherever the cross-section does not change", function()
		local arena = Config.defaults().Arena
		-- A straight's section and a curved end's share only the bank's top and the wall's top, so every strip changes
		-- in the 20-stud blend at each corner and runs between the first and last stations past the blends: 12 from
		-- each end (three 4-stud station steps past the blend's 10). The spawn room runs from the bank's foot (24) to
		-- 30: 6 wide, its middle 20 + 27 = 47 from the long axis.
		local run = arena.straightLength - 2 * 12
		local whole, between = 0, 0
		local room: Types.Piece? = nil
		local solid, glassLook = Surface.build(arena)
		for _, pieces in { solid, glassLook } do
			for _, piece in pieces do
				if piece.shape == "Block" then
					if math.abs(piece.size.Z - arena.straightLength) < 1e-3 then
						whole += 1
					elseif math.abs(piece.size.Z - run) < 1e-3 then
						between += 1
						if (piece.cframe.Position - Vector3.new(0, -0.5, -47)).Magnitude < 1e-3 then
							room = piece
						end
					end
				end
			end
		end
		expect(whole).toBe(0)
		expect(between).toBe(2 * 22)
		expect(room).never.toBeNil()
		expect(((room :: Types.Piece).size - Vector3.new(6, 1, run)).Magnitude).toBeLessThan(1e-3)
	end)
end)
