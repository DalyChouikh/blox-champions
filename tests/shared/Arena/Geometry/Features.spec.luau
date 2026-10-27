--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Centerline = require(ReplicatedStorage.Shared.Arena.Geometry.Centerline)
local Config = require(ReplicatedStorage.Shared.Config)
local Features = require(ReplicatedStorage.Shared.Arena.Geometry.Features)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local Types = require(ReplicatedStorage.Shared.Arena.Geometry.Types)

local arena = Config.defaults().Arena
local openArena = Fixtures.config({ Arena = { top = { kind = "Open" } } }).Arena
-- Station steps around each curved end.
local steps = #Centerline.sectionStations(arena, 2) - 1

-- How far across the track a point is, from the inner glass's face (u in the profile), seen from above.
local function lateral(position: Vector3): number
	local half = arena.straightLength / 2
	local fromAxis = Vector2.new(position.X - math.clamp(position.X, -half, half), position.Z).Magnitude
	return fromAxis - (arena.endRadius - arena.trackWidth / 2)
end

-- Every corner of a piece: a block's eight, a wedge's six (it has none on its slope's top edge).
local function corners(piece: Types.Piece): { Vector3 }
	local half = piece.size / 2
	local list: { Vector3 } = {}
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				if not (piece.shape == "Wedge" and y == 1 and z == -1) then
					table.insert(list, piece.cframe:PointToWorldSpace(Vector3.new(x * half.X, y * half.Y, z * half.Z)))
				end
			end
		end
	end
	return list
end

describe("Features.gates", function()
	it("spans the track at each corner, facing the travel direction, as tall as the top", function()
		local gates = Features.gates(arena)
		expect(#gates).toBe(4)
		Fixtures.expectNear(gates[1].frame.Position, Vector3.new(100, 60, -60))
		Fixtures.expectNear(gates[1].frame.LookVector, Vector3.new(-1, 0, 0))
		Fixtures.expectNear(gates[3].frame.Position, Vector3.new(-100, 60, 60))
		expect(gates[2].width).toBe(80)
		expect(gates[2].height).toBe(120)
		local open = Features.gates(openArena)
		expect(open[2].height).toBe(140)
		Fixtures.expectNear(open[1].frame.Position, Vector3.new(100, 70, -60))
	end)
end)

describe("Features.glass", function()
	it("rises from both solid tops into rideable glass up to the lips, each a slab behind its face", function()
		local glass, thickness = arena.glass, arena.surfaceThickness
		local lipStart = glass.top - glass.lipRadius
		-- Around a curved end the glass is chords along the loop: a chord's middle lies up to `sag` inside its circle
		-- (the outer glass's, the widest). A lip's strips are chords across too, their middles nearest its center.
		local sag = (arena.endRadius + arena.trackWidth / 2) * (1 - math.cos(math.pi / (2 * steps)))
		local nearest = glass.lipRadius * math.cos(math.pi / (4 * glass.lipStrips)) - sag
		local inner, outer, lips = 0, 0, 0
		for _, piece in Features.glass(arena) do
			if piece.shape == "Block" and math.abs(piece.cframe.RightVector.Y) > 0.999 then
				-- The vertical glass. A block's X runs up its face, Y out of the face toward the track, Z along it.
				local center = piece.cframe.Position
				expect(center.Y + piece.size.X / 2).toBeCloseTo(lipStart, 3)
				expect(piece.size.Y).toBeCloseTo(thickness, 4)
				local face = lateral(center + piece.cframe.UpVector * thickness / 2)
				local back = lateral(center - piece.cframe.UpVector * thickness / 2)
				if face < arena.trackWidth / 2 then
					inner += 1
					expect(face <= 1e-3 and face > -sag - 1e-3).toBe(true)
					expect(back - face).toBeCloseTo(-thickness, 2)
					expect(center.Y - piece.size.X / 2).toBeCloseTo(arena.innerBankHeight, 3)
				else
					outer += 1
					expect(face >= arena.trackWidth - sag - 1e-3 and face <= arena.trackWidth + 1e-3).toBe(true)
					expect(back - face).toBeCloseTo(thickness, 2)
					expect(center.Y - piece.size.X / 2).toBeCloseTo(arena.outerWallHeight, 3)
				end
			else
				-- A lip: its face on the chords of a quarter circle curling inward over the track, its slab outside.
				lips += 1
				for _, corner in corners(piece) do
					local u = lateral(corner)
					local lipCenter = if u < arena.trackWidth / 2
						then Vector2.new(glass.lipRadius, lipStart)
						else Vector2.new(arena.trackWidth - glass.lipRadius, lipStart)
					local distance = (Vector2.new(u, corner.Y) - lipCenter).Magnitude
					expect(distance > nearest - 1e-3 and distance < glass.lipRadius + thickness + 1e-3).toBe(true)
					expect(corner.Y > lipStart - 1e-3).toBe(true)
				end
			end
		end
		expect(inner > 0 and inner == outer).toBe(true)
		expect(lips > 0).toBe(true)
	end)

	it(
		"sweeps the vertical glass as one block per station step and per side along each straight, and each lip in "
			.. "lipStrips strips",
		function()
			local vertical, straights, lipBlocks, lipWedges = 0, 0, 0, 0
			for _, piece in Features.glass(arena) do
				if piece.shape == "Wedge" then
					lipWedges += 1
				elseif math.abs(piece.cframe.RightVector.Y) > 0.999 then
					vertical += 1
					if math.abs(piece.size.Z - arena.straightLength) < 1e-3 then
						straights += 1
					end
				else
					-- A lip's strip never changes along a straight.
					lipBlocks += 1
					expect(piece.size.Z).toBeCloseTo(arena.straightLength, 3)
				end
			end
			-- Per side: one vertical block for each straight, and one for each station step around the two curved
			-- ends. Each of the two lips: lipStrips blocks per straight, and four wedges per strip and station step
			-- around the ends.
			local strips = arena.glass.lipStrips
			expect(vertical).toBe(2 * (2 + 2 * steps))
			expect(straights).toBe(4)
			expect(lipBlocks).toBe(2 * 2 * strips)
			expect(lipWedges).toBe(2 * strips * 2 * steps * 4)
		end
	)
end)

describe("Features.top", function()
	-- Every piece's face, the side away from its slab: a block's face is its +Y side (Surface's block), and every
	-- wedge of the top lies flat, its face downward.
	local function faceCorners(piece: Types.Piece): { Vector3 }
		if piece.shape == "Wedge" then
			return Fixtures.wedgeFace(piece, -Vector3.yAxis)
		end
		local frame, half = piece.cframe, piece.size / 2
		local face = frame.Position + frame.UpVector * half.Y
		local list: { Vector3 } = {}
		for _, x in { -1, 1 } do
			for _, z in { -1, 1 } do
				table.insert(list, face + frame.RightVector * (x * half.X) + frame.LookVector * (z * half.Z))
			end
		end
		return list
	end

	it(
		"closes the arena with the top: a roof between the lips' ends, or an open map's ceiling and its strips",
		function()
			local wallTop = arena.glass.top
			local from, to = arena.glass.lipRadius, arena.trackWidth - arena.glass.lipRadius
			local blocks, wedges = 0, 0
			for _, piece in Features.top(arena) do
				if piece.shape == "Block" then
					blocks += 1
					-- The slab above its face, outside the track.
					expect(piece.cframe.UpVector.Y).toBeCloseTo(-1, 4)
				else
					wedges += 1
					for _, corner in Fixtures.wedgeFace(piece, Vector3.yAxis) do
						expect(corner.Y).toBeCloseTo(wallTop + arena.surfaceThickness, 3)
					end
				end
				for _, corner in faceCorners(piece) do
					expect(corner.Y).toBeCloseTo(wallTop, 3)
					local u = lateral(corner)
					expect(u > from - 0.05 and u < to + 0.05).toBe(true)
				end
			end
			-- One block along each straight, and four wedges for each station step around each curved end.
			expect(blocks).toBe(2)
			expect(wedges).toBe(2 * steps * 4)

			-- Strips up from both lips' ends to the ceiling (one block per straight and per station step around each
			-- end, as the vertical glass), and the ceiling as the roof was.
			local ceiling = wallTop + arena.top.ceilingAbove
			local middle = arena.trackWidth / 2
			local open = Features.top(openArena)
			expect(#open).toBe(2 + 2 * steps * 4 + 2 * (2 + 2 * steps))
			for _, piece in open do
				if piece.shape == "Block" and piece.cframe.UpVector.Y > -0.99 then
					-- A strip's slab hangs outside the track: its face points back across it.
					local center = piece.cframe.Position
					local offMiddle = math.abs(lateral(center) - middle)
					expect(math.abs(lateral(center + piece.cframe.UpVector) - middle) < offMiddle).toBe(true)
				end
				for _, corner in faceCorners(piece) do
					local u = lateral(corner)
					local onStrip = (math.abs(u - from) < 0.05 or math.abs(u - to) < 0.05)
						and corner.Y > wallTop - 1e-3
						and corner.Y < ceiling + 1e-3
					local onCeiling = math.abs(corner.Y - ceiling) < 1e-3 and u > from - 0.05 and u < to + 0.05
					expect(onStrip or onCeiling).toBe(true)
				end
			end
		end
	)
end)

describe("Features.goal", function()
	it("raises the ring on the outer wall at the goal gate, facing oncoming skaters", function()
		local goal = Features.goal(arena)
		-- The rim's outline reaches 8 studs out (ringRadius 7 + rimThickness 1), wallGap 1 from the outer glass at 80.
		Fixtures.expectNear(goal.frame.Position, Vector3.new(-100, 18, -91))
		Fixtures.expectNear(goal.frame.LookVector, Vector3.new(-1, 0, 0))
		expect(goal.openingRadius).toBe(7)
	end)

	it("rings the opening with the rim and covers it with the panel", function()
		local goal = Features.goal(arena)
		expect(#goal.rim).toBe(16)
		for _, piece in goal.rim do
			local offset = goal.frame:PointToObjectSpace(piece.cframe.Position)
			expect(offset.Magnitude).toBeCloseTo(7.5, 3)
			expect(offset.Z).toBeCloseTo(0, 3)
		end
		expect(goal.panel.shape).toBe("Cylinder")
		Fixtures.expectNear(goal.panel.cframe.Position, goal.frame.Position)
		expect(math.abs(goal.panel.cframe.RightVector:Dot(goal.frame.LookVector))).toBeCloseTo(1, 4)
		Fixtures.expectNear(goal.panel.size, Vector3.new(0.5, 14, 14))
	end)
end)

describe("Features.goal fit", function()
	local function goalWith(overrides: { [string]: any }): () -> ()
		local arenaConfig = Fixtures.config({ Arena = overrides }).Arena
		return function()
			Features.goal(arenaConfig)
		end
	end

	it("keeps the rim's farthest corner wallGap from the outer wall, whatever its number of segments", function()
		-- 20 up, so these rims clear the outer wall's foot curve beside them (a 4-segment rim no longer does under the
		-- wall's top).
		for _, segments in { 5, 6, 16 } do
			local a = Fixtures.config({ Arena = { goal = { rimSegments = segments, heightAboveFloor = 20 } } }).Arena
			local goal = Features.goal(a)
			local gate = Centerline.frameAt(a, Centerline.gateDistance(a, a.goalGateIndex))
			local farthest = -math.huge
			for _, piece in goal.rim do
				for _, side in { -1, 1 } do
					local corner = Vector3.new(side * piece.size.X / 2, piece.size.Y / 2, 0)
					farthest = math.max(farthest, gate:PointToObjectSpace(piece.cframe:PointToWorldSpace(corner)).X)
				end
			end
			expect(farthest).toBeCloseTo(a.trackWidth / 2 - a.goal.wallGap, 3)
		end
	end)

	it("rejects a ring that does not fit across the track or between the upper floor and the wall top", function()
		expect(goalWith({ goal = { wallGap = 70 } })).toThrow("Arena: the goal ring must fit across the track")
		expect(goalWith({ goal = { heightAboveFloor = 24 } })).toThrow(
			"Arena: the goal ring must sit between the upper floor and the outer wall top"
		)
		expect(goalWith({ goal = { rimSegments = 3 } })).toThrow(
			"Arena: the goal ring must sit between the upper floor and the outer wall top"
		)
	end)

	it("rejects a low ring whose rim would cut into the outer wall's foot curve at the goal gate", function()
		expect(goalWith({ stepHeight = 0, goal = { heightAboveFloor = 8, wallGap = 0.01 } })).toThrow(
			"Arena: the goal ring must clear the track's surface at the goal gate"
		)
		expect(goalWith({ stepHeight = 0, goal = { heightAboveFloor = 19.5, wallGap = 0.01 } })).never.toThrow()
	end)
end)

describe("Features markers, spawns and infield", function()
	it("hangs a flat panel on the outer wall's inner face at each gate, its top flush with the wall top", function()
		local markers = Features.markers(arena)
		expect(#markers).toBe(4)
		-- Lateral 79.5 (one surface thickness in from the wall at 80), top at 28 less half the 8-stud panel.
		Fixtures.expectNear(markers[2].cframe.Position, Vector3.new(-100, 24, -99.5))
		Fixtures.expectNear(markers[2].size, Vector3.new(1, 8, 2))
	end)

	it("lines each team up on the lower floor of its straight, mirrored across the long axis", function()
		local spawns = Features.teamSpawns(arena, 3)
		expect(#spawns.Blue).toBe(3)
		expect(#spawns.Orange).toBe(3)
		Fixtures.expectNear(spawns.Blue[1].Position, Vector3.new(10, 0, -42))
		Fixtures.expectNear(spawns.Blue[2].Position, Vector3.new(0, 0, -42))
		Fixtures.expectNear(spawns.Blue[3].Position, Vector3.new(-10, 0, -42))
		Fixtures.expectNear(spawns.Blue[1].LookVector, Vector3.new(-1, 0, 0))
		for index, blue in spawns.Blue do
			local orange = spawns.Orange[#spawns.Orange + 1 - index]
			Fixtures.expectNear(orange.Position, Vector3.new(blue.Position.X, 0, -blue.Position.Z))
			Fixtures.expectNear(orange.LookVector, -blue.LookVector)
		end
	end)

	it("drops the ball above the apex of each curved end, equally far from both teams", function()
		local balls = Features.ballSpawns(arena)
		expect(#balls).toBe(2)
		Fixtures.expectNear(balls[1].Position, Vector3.new(-160, 6, 0))
		Fixtures.expectNear(balls[2].Position, Vector3.new(160, 6, 0))
		local spawns = Features.teamSpawns(arena, 3)
		for _, ball in balls do
			expect((ball.Position - spawns.Blue[2].Position).Magnitude).toBeCloseTo(
				(ball.Position - spawns.Orange[2].Position).Magnitude,
				4
			)
		end
	end)

	it(
		"lays the infield floor between the straights at the lower floor's height, out to the inner glass's back",
		function()
			local pieces = Features.infield(arena)
			expect(pieces[1].shape).toBe("Block")
			-- 2 · (endRadius − trackWidth / 2 − surfaceThickness) = 38 deep behind the glass's slab, its top at 0.
			Fixtures.expectNear(pieces[1].cframe.Position, Vector3.new(0, -0.5, 0))
			Fixtures.expectNear(pieces[1].size, Vector3.new(200, 1, 38))
		end
	)

	-- The inner glass is flat strips between stations, so a disc would overlap them between stations.
	it(
		"lays the infield floor under each curved end as a fan of prisms that meets the inner glass's back at every "
			.. "station",
		function()
			local pieces = Features.infield(arena)
			expect(#pieces).toBe(1 + 2 * steps * 2)
			-- The glass's back, one slab behind its face: 19 studs from each curved end's center.
			local reach = arena.endRadius - arena.trackWidth / 2 - arena.surfaceThickness
			local fanCorners: { Vector3 } = {}
			for index = 2, #pieces do
				local piece = pieces[index]
				expect(piece.shape).toBe("Wedge")
				expect(piece.size.X).toBeCloseTo(arena.surfaceThickness, 4)
				for _, corner in Fixtures.wedgeFace(piece, Vector3.yAxis) do
					expect(corner.Y).toBeCloseTo(0, 3)
					local center = Vector3.new(if corner.X < 0 then -100 else 100, 0, 0)
					expect((corner - center).Magnitude <= reach + 1e-3).toBe(true)
					table.insert(fanCorners, corner)
				end
			end
			for _, section in { 2, 4 } do
				for _, distance in Centerline.sectionStations(arena, section) do
					local back = Centerline.at(arena, distance, -arena.surfaceThickness, 0).Position
					local meets = false
					for _, corner in fanCorners do
						meets = meets or (corner - back).Magnitude < 1e-3
					end
					expect(meets).toBe(true)
				end
			end
		end
	)
end)
