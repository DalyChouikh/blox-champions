--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Centerline = require(ReplicatedStorage.Shared.Arena.Geometry.Centerline)
local Config = require(ReplicatedStorage.Shared.Config)
local Features = require(ReplicatedStorage.Shared.Arena.Geometry.Features)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)

local arena = Config.defaults().Arena

local function near(actual: Vector3, expected: Vector3)
	expect((actual - expected).Magnitude).toBeLessThan(1e-3)
end

describe("Features.gates", function()
	it("spans the track at each corner, facing the travel direction, as tall as the outer wall", function()
		local gates = Features.gates(arena)
		expect(#gates).toBe(4)
		near(gates[1].frame.Position, Vector3.new(80, 14, -60))
		near(gates[1].frame.LookVector, Vector3.new(-1, 0, 0))
		near(gates[3].frame.Position, Vector3.new(-80, 14, 60))
		expect(gates[2].width).toBe(44)
		expect(gates[2].height).toBe(28)
	end)
end)

describe("Features.goal", function()
	it("raises the ring on the outer wall at the goal gate, facing oncoming skaters", function()
		local goal = Features.goal(arena)
		near(goal.frame.Position, Vector3.new(-80, 18, -73))
		near(goal.frame.LookVector, Vector3.new(-1, 0, 0))
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
		near(goal.panel.cframe.Position, goal.frame.Position)
		expect(math.abs(goal.panel.cframe.RightVector:Dot(goal.frame.LookVector))).toBeCloseTo(1, 4)
		near(goal.panel.size, Vector3.new(0.5, 14, 14))
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
	it("stands a pillar on the outer wall top at each gate", function()
		local markers = Features.markers(arena)
		expect(#markers).toBe(4)
		near(markers[2].cframe.Position, Vector3.new(-80, 32, -82.5))
		near(markers[2].size, Vector3.new(2, 8, 2))
	end)

	it("lines each team up on the lower floor of its straight, mirrored across the long axis", function()
		local spawns = Features.teamSpawns(arena, 3)
		expect(#spawns.Blue).toBe(3)
		expect(#spawns.Orange).toBe(3)
		near(spawns.Blue[1].Position, Vector3.new(10, 0, -53))
		near(spawns.Blue[2].Position, Vector3.new(0, 0, -53))
		near(spawns.Blue[3].Position, Vector3.new(-10, 0, -53))
		near(spawns.Blue[1].LookVector, Vector3.new(-1, 0, 0))
		for index, blue in spawns.Blue do
			local orange = spawns.Orange[#spawns.Orange + 1 - index]
			near(orange.Position, Vector3.new(blue.Position.X, 0, -blue.Position.Z))
			near(orange.LookVector, -blue.LookVector)
		end
	end)

	it("drops the ball above the apex of each curved end, equally far from both teams", function()
		local balls = Features.ballSpawns(arena)
		expect(#balls).toBe(2)
		near(balls[1].Position, Vector3.new(-140, 6, 0))
		near(balls[2].Position, Vector3.new(140, 6, 0))
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
		near(pieces[1].cframe.Position, Vector3.new(0, 10, 0))
		near(pieces[1].size, Vector3.new(160, 20, 74))
	end)

	-- The inner wall is flat strips between stations, so a cylinder would overlap them between stations.
	it("fills each curved end with a fan of prisms that meets the back of the wall's slab at every station", function()
		local pieces = Features.infield(arena)
		expect(#pieces).toBe(1 + 2 * 48 * 2)
		local corners: { Vector3 } = {}
		for index = 2, #pieces do
			local piece = pieces[index]
			expect(piece.shape).toBe("Wedge")
			expect(piece.size.X).toBeCloseTo(20, 4)
			for _, corner in Fixtures.wedgeFace(piece, Vector3.yAxis) do
				expect(corner.Y).toBeCloseTo(20, 3)
				local center = Vector3.new(if corner.X < 0 then -80 else 80, 20, 0)
				expect((corner - center).Magnitude <= 37 + 1e-3).toBe(true)
				table.insert(corners, corner)
			end
		end
		for _, section in { 2, 4 } do
			for _, distance in Centerline.sectionStations(arena, section) do
				local back = Centerline.at(arena, distance, -arena.surfaceThickness, 20).Position
				local meets = false
				for _, corner in corners do
					meets = meets or (corner - back).Magnitude < 1e-3
				end
				expect(meets).toBe(true)
			end
		end
	end)
end)
