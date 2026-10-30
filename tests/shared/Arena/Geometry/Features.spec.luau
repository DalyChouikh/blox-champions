--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Centerline = require(ReplicatedStorage.Shared.Arena.Geometry.Centerline)
local Config = require(ReplicatedStorage.Shared.Config)
local Features = require(ReplicatedStorage.Shared.Arena.Geometry.Features)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local PartSize = require(ReplicatedStorage.Shared.Util.PartSize)
local Profile = require(ReplicatedStorage.Shared.Arena.Geometry.Profile)
local Surface = require(ReplicatedStorage.Shared.Arena.Geometry.Surface)
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
		local closeTo = Fixtures.closeTo
		local check, expectNone = Fixtures.checks()
		local inner, outer, lips = 0, 0, 0
		for index, piece in Features.glass(arena) do
			if piece.shape == "Block" and math.abs(piece.cframe.RightVector.Y) > 0.999 then
				-- The vertical glass. A block's X runs up its face, Y out of the face toward the track, Z along it.
				local center = piece.cframe.Position
				local bottom = center.Y - piece.size.X / 2
				check(closeTo(center.Y + piece.size.X / 2, lipStart, 3), "a wall's glass up to the lip", index)
				check(closeTo(piece.size.Y, thickness, 4), "a wall's glass surfaceThickness thick", index)
				local face = lateral(center + piece.cframe.UpVector * thickness / 2)
				local back = lateral(center - piece.cframe.UpVector * thickness / 2)
				if face < arena.trackWidth / 2 then
					inner += 1
					check(face <= 1e-3 and face > -sag - 1e-3, "the inner glass's face at the track's edge", index)
					check(closeTo(back - face, -thickness, 2), "the inner glass's slab behind its face", index)
					check(closeTo(bottom, arena.innerBankHeight, 3), "the inner glass from the bank's top", index)
				else
					outer += 1
					local onEdge = face >= arena.trackWidth - sag - 1e-3 and face <= arena.trackWidth + 1e-3
					check(onEdge, "the outer glass's face at the track's edge", index)
					check(closeTo(back - face, thickness, 2), "the outer glass's slab behind its face", index)
					check(closeTo(bottom, arena.outerWallHeight, 3), "the outer glass from the wall's top", index)
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
					local onCircle = distance > nearest - 1e-3 and distance < glass.lipRadius + thickness + 1e-3
					check(onCircle, "a lip's corner on its quarter circle", index)
					check(corner.Y > lipStart - 1e-3, "a lip's corner above where the lip starts", index)
				end
			end
		end
		expectNone()
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
			local closeTo = Fixtures.closeTo
			local check, expectNone = Fixtures.checks()
			local blocks, wedges = 0, 0
			for index, piece in Features.top(arena) do
				if piece.shape == "Block" then
					blocks += 1
					-- The slab above its face, outside the track.
					check(closeTo(piece.cframe.UpVector.Y, -1, 4), "a roof block's slab above its face", index)
				else
					wedges += 1
					for _, corner in Fixtures.wedgeFace(piece, Vector3.yAxis) do
						local onSlab = closeTo(corner.Y, wallTop + arena.surfaceThickness, 3)
						check(onSlab, "a roof wedge's slab above its face", index)
					end
				end
				for _, corner in faceCorners(piece) do
					check(closeTo(corner.Y, wallTop, 3), "the roof's face at the walls' top", index)
					local u = lateral(corner)
					check(u > from - 0.05 and u < to + 0.05, "the roof between the lips' ends", index)
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
			for index, piece in open do
				if piece.shape == "Block" and piece.cframe.UpVector.Y > -0.99 then
					-- A strip's slab hangs outside the track: its face points back across it.
					local center = piece.cframe.Position
					local offMiddle = math.abs(lateral(center) - middle)
					local outside = math.abs(lateral(center + piece.cframe.UpVector) - middle) < offMiddle
					check(outside, "an open map's strip with its slab outside the track", index)
				end
				for _, corner in faceCorners(piece) do
					local u = lateral(corner)
					local onStrip = (math.abs(u - from) < 0.05 or math.abs(u - to) < 0.05)
						and corner.Y > wallTop - 1e-3
						and corner.Y < ceiling + 1e-3
					local onCeiling = math.abs(corner.Y - ceiling) < 1e-3 and u > from - 0.05 and u < to + 0.05
					check(onStrip or onCeiling, "an open map's top on its strips or its ceiling", index)
				end
			end
			expectNone()
		end
	)
end)

describe("Features.goal", function()
	-- R7: the ring hangs over the track, 0.75 of the way across (u 60): 80 out from the long axis at gate 2.
	it(
		"hangs the ring over the track at the goal gate, goal.across of the way to the outer glass, facing oncoming "
			.. "skaters",
		function()
			local goal = Features.goal(arena)
			Fixtures.expectNear(goal.frame.Position, Vector3.new(-100, 29, -80))
			Fixtures.expectNear(goal.frame.LookVector, Vector3.new(-1, 0, 0))
			expect(goal.openingRadius).toBe(7)
		end
	)

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

	-- Arena spec §5.3: decoration in the goal gate's plane.
	it(
		"hangs the ring from an arm: a post from the rim's top, and a beam out to the outer glass, under the lips",
		function()
			local goal = Features.goal(arena)
			local ring, arm = arena.goal, arena.goal.arm
			local gate = Centerline.frameAt(arena, Centerline.gateDistance(arena, arena.goalGateIndex))
			-- A piece's extent in the gate's frame: x across the track from its middle, y up, z along the track.
			local function extent(piece: Types.Piece): (Vector3, Vector3)
				local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
				for _, corner in corners(piece) do
					local at = gate:PointToObjectSpace(corner)
					low, high = low:Min(at), high:Max(at)
				end
				return low, high
			end
			local half, side = arena.trackWidth / 2, arm.thickness / 2
			-- Over the ring's centre (u 60), and the rim's flat top (37).
			local centre = ring.across * arena.trackWidth - half
			local rimTop = ring.heightAboveFloor + ring.ringRadius + ring.rimThickness
			expect(#goal.arm).toBe(2)
			-- The post: 14 tall, from the rim's top up to the arm's height (51).
			local low, high = extent(goal.arm[1])
			Fixtures.expectNear(low, Vector3.new(centre - side, rimTop, -side))
			Fixtures.expectNear(high, Vector3.new(centre + side, arm.height, side))
			-- The beam: 20 long, at the arm's height, from over the ring's centre out to the outer glass's face (u 80).
			low, high = extent(goal.arm[2])
			Fixtures.expectNear(low, Vector3.new(centre, arm.height - side, -side))
			Fixtures.expectNear(high, Vector3.new(half, arm.height + side, side))
			-- At or over where the lips start (108), the beam would cross into them.
			for _, height in { 108, 110 } do
				expect(function()
					Features.goal(Fixtures.config({ Arena = { goal = { arm = { height = height } } } }).Arena)
				end).toThrow("Arena: the goal's arm must stay under the lips")
			end
		end
	)
end)

describe("Features.goal fit", function()
	local function goalWith(overrides: { [string]: any }): () -> ()
		local arenaConfig = Fixtures.config({ Arena = overrides }).Arena
		return function()
			Features.goal(arenaConfig)
		end
	end

	-- Its centre 71.5 (or 8.5) across, so the circle its faces touch (radius ringRadius + rimThickness, 8) ends 0.5
	-- inside the outer (or inner) glass. A rim of 4 or 16 segments turns a face toward each glass and fits; one of 5 or
	-- 6 turns a corner toward it, reaching 9.405 or 9.238 from the centre, and does not. High up (60, its arm at 80),
	-- it clears the floor and its arm.
	it("keeps the rim inside the glass, judged by its corners, whatever its number of segments", function()
		for _, across in { 0.89375, 0.10625 } do
			for _, segments in { 4, 5, 6, 16 } do
				local fit = goalWith({
					goal = { rimSegments = segments, heightAboveFloor = 60, across = across, arm = { height = 80 } },
				})
				if segments == 4 or segments == 16 then
					expect(fit).never.toThrow()
				else
					expect(fit).toThrow("Arena: the goal ring must stay inside the glass")
				end
			end
		end
	end)

	it("rejects a ring outside the glass or over its arm", function()
		for _, across in { 0.05, 0.95 } do
			expect(goalWith({ goal = { across = across } })).toThrow("Arena: the goal ring must stay inside the glass")
		end
		-- The rim's top is 37: an arm there or lower leaves no room for its post.
		for _, height in { 36, 37 } do
			expect(goalWith({ goal = { arm = { height = height } } })).toThrow(
				"Arena: the goal ring must hang under its arm"
			)
		end
	end)

	-- At the goal gate the floor under the ring is the halfway blend of the two sections, rising toward the outer
	-- glass: under the rim's outer bottom corner (1.59 past the centre, 8 below it, u 61.59) it stands 11.50 high, so a
	-- ring whose centre is at 19 cuts into it and one at 20 clears it.
	it("rejects a low ring whose rim would cut into the floor under it", function()
		expect(goalWith({ goal = { heightAboveFloor = 19 } })).toThrow(
			"Arena: the goal ring must clear the track's surface at the goal gate"
		)
		expect(goalWith({ goal = { heightAboveFloor = 20 } })).never.toThrow()
	end)
end)

describe("Features.gatePanels", function()
	-- The area a piece's face covers in its plane: a block's rectangle, or a wedge's right triangle.
	local function faceArea(piece: Types.Piece): number
		return if piece.shape == "Block" then piece.size.X * piece.size.Z else piece.size.Y * piece.size.Z / 2
	end

	-- The area between two outlines that both run across the track: the shoelace formula round the bottom one, then
	-- the top one run back.
	local function areaBetween(bottom: { Vector2 }, top: { Vector2 }): number
		local ring = table.clone(bottom)
		for index = #top, 1, -1 do
			table.insert(ring, top[index])
		end
		local twice = 0
		for index, point in ring do
			local nextPoint = ring[index % #ring + 1]
			twice += point.X * nextPoint.Y - nextPoint.X * point.Y
		end
		return math.abs(twice) / 2
	end

	-- The wall (R18, amended 2026-10-27): glass across the whole track, from the surface at the gate (a straight's and
	-- a curved end's sections blended halfway there) up to the walls' top as built, breaking at every bend of either
	-- outline.
	it("fills each gate with glass from the track's surface up to the walls' top", function()
		local depth = arena.gatePanel.depth
		local half = arena.trackWidth / 2
		local distance = Centerline.gateDistance(arena, 1)
		local gate = Centerline.frameAt(arena, distance)
		local bottom, top = Surface.section(arena, distance), Profile.topOutline(arena)
		local function height(outline: { Vector2 }, u: number): number
			return Profile.heightAt(outline, math.clamp(u, 0, arena.trackWidth)) :: number
		end
		-- The corners on the gate's plane, as (u, y), and how far any corner lies behind it.
		local face: { Vector2 } = {}
		local deepest, area = 0, 0
		local check, expectNone = Fixtures.checks()
		for index, piece in Features.gatePanels(arena)[1].pieces do
			area += faceArea(piece)
			for _, corner in corners(piece) do
				-- In the gate's frame: x across the track from its middle, z along it.
				local at = gate:PointToObjectSpace(corner)
				local u = at.X + half
				check(math.abs(at.Z) <= depth + 1e-3, "a wall's corner within gatePanel.depth of the gate", index)
				deepest = math.max(deepest, math.abs(at.Z))
				local between = at.Y > height(bottom, u) - 1e-3 and at.Y < height(top, u) + 1e-3
				check(between, "a wall's corner between the surface and the walls' top", index)
				if math.abs(at.Z) < 1e-3 then
					table.insert(face, Vector2.new(u, at.Y))
				end
			end
		end
		expectNone()
		local function hasCorner(u: number, y: number): boolean
			for _, corner in face do
				if (corner - Vector2.new(u, y)).Magnitude < 1e-3 then
					return true
				end
			end
			return false
		end
		-- A break at every point of either outline: the wall has a corner there on both of them.
		for _, outline in { bottom, top } do
			for _, point in outline do
				local u = point.X
				expect(hasCorner(u, height(bottom, u)) and hasCorner(u, height(top, u))).toBe(true)
			end
		end
		-- It meets the bank's top and its foot (halfway between a curved end's 16 and a straight's 24), the lips and
		-- the roof.
		expect(hasCorner(0, arena.innerBankHeight)).toBe(true)
		expect(hasCorner(20, 0)).toBe(true)
		expect(hasCorner(0, Profile.lipStart(arena)) and hasCorner(arena.trackWidth, Profile.lipStart(arena))).toBe(
			true
		)
		expect(hasCorner(arena.glass.lipRadius, arena.glass.top)).toBe(true)
		-- No gap and no overlap: the slices' faces cover the area between the outlines.
		expect(area).toBeCloseTo(areaBetween(bottom, top), 1)
		-- gatePanel.depth thick along the track.
		expect(deepest).toBeCloseTo(depth, 3)
	end)

	it("builds each wall from a slice between every two breaks, in gate order", function()
		local panels = Features.gatePanels(arena)
		expect(#panels).toBe(Centerline.gateCount)
		local half = arena.trackWidth / 2
		for gate, panel in panels do
			-- 28 breaks (the surface's 21 points and the top's 10, three of them at a glass face twice or thrice), so
			-- 27 slices. None is a rectangle: the halfway blend at a gate is flat nowhere. Each is four wedges.
			local blocks = 0
			for _, piece in panel.pieces do
				if piece.shape == "Block" then
					blocks += 1
				end
			end
			expect(blocks).toBe(0)
			expect(#panel.pieces).toBe(27 * 4)
			-- Its pivot is the wall's middle, halfway between the surface and the roof, facing the travel direction.
			local distance = Centerline.gateDistance(arena, gate)
			local floor = Profile.heightAt(Surface.section(arena, distance), half) :: number
			local middle = Centerline.at(arena, distance, half, (floor + arena.glass.top) / 2)
			Fixtures.expectNear(panel.pivot.Position, middle.Position)
			Fixtures.expectNear(panel.pivot.LookVector, middle.LookVector)
		end
	end)

	-- With the inner lip's end half a smallest part before the bank's foot at a gate (u 20, halfway between a curved
	-- end's 16 and a straight's 24), the two outlines bend 0.0005 apart: a slice between the bends would be thinner
	-- than Roblox builds.
	it("merges breaks closer than Roblox's smallest part", function()
		local close = Fixtures.config({ Arena = { glass = { lipRadius = 20 - PartSize.MIN / 2 } } }).Arena
		for _, panel in Features.gatePanels(close) do
			for _, piece in panel.pieces do
				local size = piece.size
				expect(math.min(size.X, size.Y, size.Z) >= PartSize.MIN).toBe(true)
			end
		end
	end)
end)

describe("Features spawns and infield", function()
	it("lines each team up in the spawn room of its straight, mirrored across the long axis", function()
		local spawns = Features.teamSpawns(arena, 3)
		expect(#spawns.Blue).toBe(3)
		expect(#spawns.Orange).toBe(3)
		-- The spawn room's middle, u (24 + 30) / 2 = 27 from the inner glass's face at 20: 47 off the long axis.
		Fixtures.expectNear(spawns.Blue[1].Position, Vector3.new(10, 0, -47))
		Fixtures.expectNear(spawns.Blue[2].Position, Vector3.new(0, 0, -47))
		Fixtures.expectNear(spawns.Blue[3].Position, Vector3.new(-10, 0, -47))
		Fixtures.expectNear(spawns.Blue[1].LookVector, Vector3.new(-1, 0, 0))
		for index, blue in spawns.Blue do
			local orange = spawns.Orange[#spawns.Orange + 1 - index]
			Fixtures.expectNear(orange.Position, Vector3.new(blue.Position.X, 0, -blue.Position.Z))
			Fixtures.expectNear(orange.LookVector, -blue.LookVector)
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
