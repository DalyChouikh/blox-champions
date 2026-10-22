--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Centerline = require(ReplicatedStorage.Shared.Arena.Geometry.Centerline)
local Config = require(ReplicatedStorage.Shared.Config)
local Features = require(ReplicatedStorage.Shared.Arena.Geometry.Features)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)

local arena = Config.defaults().Arena

describe("Features.gates", function()
	it("spans the track at each corner, facing the travel direction, as tall as the roof", function()
		local gates = Features.gates(arena)
		expect(#gates).toBe(4)
		Fixtures.expectNear(gates[1].frame.Position, Vector3.new(80, 25, -60))
		Fixtures.expectNear(gates[1].frame.LookVector, Vector3.new(-1, 0, 0))
		Fixtures.expectNear(gates[3].frame.Position, Vector3.new(-80, 25, 60))
		expect(gates[2].width).toBe(44)
		expect(gates[2].height).toBe(50)
	end)
end)

describe("Features.goal", function()
	it("raises the ring on the outer wall at the goal gate, facing oncoming skaters", function()
		local goal = Features.goal(arena)
		Fixtures.expectNear(goal.frame.Position, Vector3.new(-80, 18, -73))
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
		for _, segments in { 4, 5, 6, 16 } do
			local a = Fixtures.config({ Arena = { goal = { rimSegments = segments } } }).Arena
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
		expect(goalWith({ goal = { wallGap = 30 } })).toThrow("Arena: the goal ring must fit across the track")
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
		expect(goalWith({ stepHeight = 0, goal = { heightAboveFloor = 12, wallGap = 0.01 } })).never.toThrow()
	end)
end)

describe("Features markers, spawns and infield", function()
	it("hangs a flat panel on the outer wall's inner face at each gate, its top flush with the wall top", function()
		local markers = Features.markers(arena)
		expect(#markers).toBe(4)
		-- Lateral 43.5 (one surface thickness in from the wall at 44), top at 28 less half the 8-stud panel.
		Fixtures.expectNear(markers[2].cframe.Position, Vector3.new(-80, 24, -81.5))
		Fixtures.expectNear(markers[2].size, Vector3.new(1, 8, 2))
	end)

	it("lines each team up on the lower floor of its straight, mirrored across the long axis", function()
		local spawns = Features.teamSpawns(arena, 3)
		expect(#spawns.Blue).toBe(3)
		expect(#spawns.Orange).toBe(3)
		Fixtures.expectNear(spawns.Blue[1].Position, Vector3.new(10, 0, -53))
		Fixtures.expectNear(spawns.Blue[2].Position, Vector3.new(0, 0, -53))
		Fixtures.expectNear(spawns.Blue[3].Position, Vector3.new(-10, 0, -53))
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
		Fixtures.expectNear(balls[1].Position, Vector3.new(-140, 6, 0))
		Fixtures.expectNear(balls[2].Position, Vector3.new(140, 6, 0))
		local spawns = Features.teamSpawns(arena, 3)
		for _, ball in balls do
			expect((ball.Position - spawns.Blue[2].Position).Magnitude).toBeCloseTo(
				(ball.Position - spawns.Orange[2].Position).Magnitude,
				4
			)
		end
	end)

	it("fills the infield between the straights up to the inner wall top, tucked behind the wall's slab", function()
		local pieces = Features.infield(arena)
		expect(pieces[1].shape).toBe("Block")
		Fixtures.expectNear(pieces[1].cframe.Position, Vector3.new(0, 14, 0))
		Fixtures.expectNear(pieces[1].size, Vector3.new(160, 28, 74))
	end)

	-- The inner wall is flat strips between stations, so a cylinder would overlap them between stations.
	it("fills each curved end with a fan of prisms that meets the back of the wall's slab at every station", function()
		local pieces = Features.infield(arena)
		expect(#pieces).toBe(1 + 2 * 48 * 2)
		local corners: { Vector3 } = {}
		for index = 2, #pieces do
			local piece = pieces[index]
			expect(piece.shape).toBe("Wedge")
			expect(piece.size.X).toBeCloseTo(28, 4)
			for _, corner in Fixtures.wedgeFace(piece, Vector3.yAxis) do
				expect(corner.Y).toBeCloseTo(28, 3)
				local center = Vector3.new(if corner.X < 0 then -80 else 80, 28, 0)
				expect((corner - center).Magnitude <= 37 + 1e-3).toBe(true)
				table.insert(corners, corner)
			end
		end
		for _, section in { 2, 4 } do
			for _, distance in Centerline.sectionStations(arena, section) do
				local back = Centerline.at(arena, distance, -arena.surfaceThickness, 28).Position
				local meets = false
				for _, corner in corners do
					meets = meets or (corner - back).Magnitude < 1e-3
				end
				expect(meets).toBe(true)
			end
		end
	end)
end)
