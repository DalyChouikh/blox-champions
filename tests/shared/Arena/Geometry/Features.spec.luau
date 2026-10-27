--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Centerline = require(ReplicatedStorage.Shared.Arena.Geometry.Centerline)
local Config = require(ReplicatedStorage.Shared.Config)
local Features = require(ReplicatedStorage.Shared.Arena.Geometry.Features)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)

local arena = Config.defaults().Arena
-- Glass thicker than the surface's slabs, so a rule that took one thickness for the other shows. It shares every
-- other length with `arena`.
local thickGlass = Fixtures.config({ Arena = { barrier = { thickness = 2 } } }).Arena

-- How far across the track a point is, from the inner glass's face (u in the profile), seen from above.
local function lateral(position: Vector3): number
	local half = arena.straightLength / 2
	local fromAxis = Vector2.new(position.X - math.clamp(position.X, -half, half), position.Z).Magnitude
	return fromAxis - (arena.endRadius - arena.trackWidth / 2)
end

describe("Features.gates", function()
	it("spans the track at each corner, facing the travel direction, as tall as the glass", function()
		local gates = Features.gates(arena)
		expect(#gates).toBe(4)
		Fixtures.expectNear(gates[1].frame.Position, Vector3.new(100, 42.5, -70))
		Fixtures.expectNear(gates[1].frame.LookVector, Vector3.new(-1, 0, 0))
		Fixtures.expectNear(gates[3].frame.Position, Vector3.new(-100, 42.5, 70))
		expect(gates[2].width).toBe(60)
		expect(gates[2].height).toBe(85)
	end)
end)

describe("Features.barriers", function()
	it(
		"stands the inner glass on the bank's top and the outer glass on the outer wall's top, up to barrier.top, "
			.. "each a slab behind its face",
		function()
			local thickness = thickGlass.barrier.thickness
			local inner, outer = 0, 0
			for _, piece in Features.barriers(thickGlass) do
				-- A block's X runs up its face, Y out of the face toward the track, Z along the track.
				expect(math.abs(piece.cframe.RightVector.Y)).toBeCloseTo(1, 4)
				local center = piece.cframe.Position
				expect(center.Y + piece.size.X / 2).toBeCloseTo(arena.barrier.top, 3)
				expect(piece.size.Y).toBeCloseTo(thickness, 4)
				local face = lateral(center + piece.cframe.UpVector * thickness / 2)
				local back = lateral(center - piece.cframe.UpVector * thickness / 2)
				-- A curved end's glass is flat chords: a chord's middle lies a little inside its circle.
				if face < arena.trackWidth / 2 then
					inner += 1
					expect(face <= 1e-3 and face > -0.05).toBe(true)
					expect(back - face).toBeCloseTo(-thickness, 2)
					expect(center.Y - piece.size.X / 2).toBeCloseTo(arena.innerBankHeight, 3)
				else
					outer += 1
					expect(face >= arena.trackWidth - 0.05 and face <= arena.trackWidth + 1e-3).toBe(true)
					expect(back - face).toBeCloseTo(thickness, 2)
					expect(center.Y - piece.size.X / 2).toBeCloseTo(arena.outerWallHeight, 3)
				end
			end
			expect(inner > 0 and inner == outer).toBe(true)
		end
	)

	it("builds each glass strip from one block per station step, one per side along each straight", function()
		local pieces = Features.barriers(arena)
		local steps = #Centerline.sectionStations(arena, 2) - 1
		-- Per side: one block for each straight, and one for each station step around the two curved ends.
		expect(#pieces).toBe(2 * (2 + 2 * steps))
		local straights = 0
		for _, piece in pieces do
			expect(piece.shape).toBe("Block")
			if math.abs(piece.size.Z - arena.straightLength) < 1e-3 then
				straights += 1
			end
		end
		expect(straights).toBe(4)
	end)
end)

describe("Features.goal", function()
	it("raises the ring on the outer wall at the goal gate, facing oncoming skaters", function()
		local goal = Features.goal(arena)
		-- The rim's outline reaches 8 studs out (ringRadius 7 + rimThickness 1), wallGap 1 from the wall at 60.
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
		-- 20 up, so the coarsest rims clear the outer wall's foot curve beside them.
		for _, segments in { 4, 5, 6, 16 } do
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
		expect(goalWith({ goal = { wallGap = 50 } })).toThrow("Arena: the goal ring must fit across the track")
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
		expect(goalWith({ stepHeight = 0, goal = { heightAboveFloor = 16, wallGap = 0.01 } })).never.toThrow()
	end)
end)

describe("Features markers, spawns and infield", function()
	it("hangs a flat panel on the outer wall's inner face at each gate, its top flush with the wall top", function()
		local markers = Features.markers(arena)
		expect(#markers).toBe(4)
		-- Lateral 59.5 (one surface thickness in from the wall at 60), top at 28 less half the 8-stud panel.
		Fixtures.expectNear(markers[2].cframe.Position, Vector3.new(-100, 24, -99.5))
		Fixtures.expectNear(markers[2].size, Vector3.new(1, 8, 2))
	end)

	it("lines each team up on the lower floor of its straight, mirrored across the long axis", function()
		local spawns = Features.teamSpawns(arena, 3)
		expect(#spawns.Blue).toBe(3)
		expect(#spawns.Orange).toBe(3)
		Fixtures.expectNear(spawns.Blue[1].Position, Vector3.new(10, 0, -57))
		Fixtures.expectNear(spawns.Blue[2].Position, Vector3.new(0, 0, -57))
		Fixtures.expectNear(spawns.Blue[3].Position, Vector3.new(-10, 0, -57))
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
		Fixtures.expectNear(balls[1].Position, Vector3.new(-170, 6, 0))
		Fixtures.expectNear(balls[2].Position, Vector3.new(170, 6, 0))
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
			local pieces = Features.infield(thickGlass)
			expect(pieces[1].shape).toBe("Block")
			-- 2 · (endRadius − trackWidth / 2 − barrier.thickness) = 76 deep behind 2-stud glass, its top at 0.
			Fixtures.expectNear(pieces[1].cframe.Position, Vector3.new(0, -0.5, 0))
			Fixtures.expectNear(pieces[1].size, Vector3.new(200, 1, 76))
		end
	)

	-- The inner glass is flat strips between stations, so a disc would overlap them between stations.
	it(
		"lays the infield floor under each curved end as a fan of prisms that meets the inner glass's back at every "
			.. "station",
		function()
			local pieces = Features.infield(thickGlass)
			local steps = #Centerline.sectionStations(arena, 2) - 1
			expect(#pieces).toBe(1 + 2 * steps * 2)
			local corners: { Vector3 } = {}
			for index = 2, #pieces do
				local piece = pieces[index]
				expect(piece.shape).toBe("Wedge")
				expect(piece.size.X).toBeCloseTo(arena.surfaceThickness, 4)
				for _, corner in Fixtures.wedgeFace(piece, Vector3.yAxis) do
					expect(corner.Y).toBeCloseTo(0, 3)
					local center = Vector3.new(if corner.X < 0 then -100 else 100, 0, 0)
					expect((corner - center).Magnitude <= 38 + 1e-3).toBe(true)
					table.insert(corners, corner)
				end
			end
			for _, section in { 2, 4 } do
				for _, distance in Centerline.sectionStations(arena, section) do
					local back = Centerline.at(arena, distance, -thickGlass.barrier.thickness, 0).Position
					local meets = false
					for _, corner in corners do
						meets = meets or (corner - back).Magnitude < 1e-3
					end
					expect(meets).toBe(true)
				end
			end
		end
	)
end)
