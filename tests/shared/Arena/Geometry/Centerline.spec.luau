--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Centerline = require(ReplicatedStorage.Shared.Arena.Geometry.Centerline)
local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)

local arena = Config.defaults().Arena

describe("Centerline", function()
	it("is two straights and two half circles long", function()
		expect(Centerline.length(arena)).toBeCloseTo(2 * 200 + 2 * math.pi * 60, 4)
	end)

	it("places the gates at the four corners in counter-clockwise travel order, outer wall on the right", function()
		local expected = {
			{ Vector3.new(100, 0, -60), Vector3.new(-1, 0, 0) },
			{ Vector3.new(-100, 0, -60), Vector3.new(-1, 0, 0) },
			{ Vector3.new(-100, 0, 60), Vector3.new(1, 0, 0) },
			{ Vector3.new(100, 0, 60), Vector3.new(1, 0, 0) },
		}
		for gate, pair in expected do
			local frame = Centerline.frameAt(arena, Centerline.gateDistance(arena, gate))
			Fixtures.expectNear(frame.Position, pair[1])
			Fixtures.expectNear(frame.LookVector, pair[2])
		end
		Fixtures.expectNear(Centerline.frameAt(arena, 0).RightVector, Vector3.new(0, 0, -1))
		Fixtures.expectNear(
			Centerline.frameAt(arena, Centerline.gateDistance(arena, 3)).RightVector,
			Vector3.new(0, 0, 1)
		)
	end)

	it("turns left through each curved end, closes the loop, and offsets across the track", function()
		local apex = Centerline.frameAt(arena, 200 + 30 * math.pi)
		Fixtures.expectNear(apex.Position, Vector3.new(-160, 0, 0))
		Fixtures.expectNear(apex.LookVector, Vector3.new(0, 0, 1))
		Fixtures.expectNear(apex.RightVector, Vector3.new(-1, 0, 0))
		Fixtures.expectNear(
			Centerline.frameAt(arena, Centerline.length(arena)).Position,
			Centerline.frameAt(arena, 0).Position
		)
		Fixtures.expectNear(Centerline.at(arena, 100, 0, 20).Position, Vector3.new(0, 20, -20))
	end)

	-- The carrier's beam follows the ball with it: the inverse of `at` for any point across the track.
	it("finds how far along the track a point is, on both straights and around both ends", function()
		-- 0 and 50 on the top straight, 230 around the left end, 400 on the bottom straight, 560 and 700 around the
		-- right end.
		for _, distance in { 0, 50, 230, 400, 560, 700 } do
			for _, lateral in { 5, 40, 75 } do
				local point = Centerline.at(arena, distance, lateral, 5).Position
				expect(Centerline.distanceOf(arena, point)).toBeCloseTo(distance, 3)
			end
		end
		-- Just before gate 1 it is nearly a lap, not nearly 0.
		local length = Centerline.length(arena)
		local last = Centerline.at(arena, length - 0.01, 40, 5).Position
		expect(Centerline.distanceOf(arena, last)).toBeCloseTo(length - 0.01, 3)
	end)

	-- In plain numbers, so a caller placing a part every frame allocates nothing.
	it("poses a point and its heading in plain numbers, the same as frameAt", function()
		for _, distance in { 0, 250, 700 } do
			local point, yaw = Centerline.pose(arena, distance, 70, 5)
			Fixtures.expectNear(point, Centerline.at(arena, distance, 70, 5).Position)
			-- Roblox's Orientation Y: CFrame.Angles(0, yaw, 0) looks along (-sin yaw, 0, -cos yaw).
			Fixtures.expectNear(
				Vector3.new(-math.sin(yaw), 0, -math.cos(yaw)),
				Centerline.frameAt(arena, distance).LookVector
			)
		end
		-- 50 into the left end: turned 50 / endRadius radians from heading -X toward +Z.
		local _, yaw = Centerline.pose(arena, 250, 40, 0)
		local angle = 50 / arena.endRadius
		Fixtures.expectNear(
			Vector3.new(-math.sin(yaw), 0, -math.cos(yaw)),
			Vector3.new(-math.cos(angle), 0, math.sin(angle))
		)
	end)

	it("puts stations at most segmentLength apart around the whole loop, one on every gate", function()
		local stations = Centerline.stations(arena)
		-- 50 on each straight (200 / 4) and 48 around each curved end (188.5 / 4, rounded up).
		expect(#stations).toBe(196)
		for gate = 1, 4 do
			expect(table.find(stations, Centerline.gateDistance(arena, gate))).never.toBeNil()
		end
		for index = 2, #stations do
			local gap = stations[index] - stations[index - 1]
			expect(gap > 0 and gap <= arena.segmentLength + 1e-9).toBe(true)
		end
		expect(Centerline.length(arena) - stations[#stations] <= arena.segmentLength + 1e-9).toBe(true)
	end)

	it("lists one section's stations from its start to its end", function()
		local curve = Centerline.sectionStations(arena, 2)
		expect(#curve).toBe(49)
		expect(curve[1]).toBe(Centerline.gateDistance(arena, 2))
		expect(curve[49]).toBeCloseTo(Centerline.gateDistance(arena, 3), 9)
		local stations = Centerline.stations(arena)
		expect(stations[51]).toBe(curve[1])
		expect(stations[52]).toBe(curve[2])
	end)

	it("eases from a straight's cross-section (1) into a curved end's (0) around each corner", function()
		expect(Centerline.straightness(arena, 100)).toBe(1)
		expect(Centerline.straightness(arena, 200 + 30 * math.pi)).toBe(0)
		expect(Centerline.straightness(arena, 200)).toBeCloseTo(0.5)
		expect(Centerline.straightness(arena, 190)).toBeCloseTo(1)
		expect(Centerline.straightness(arena, 210)).toBeCloseTo(0)
		expect(Centerline.straightness(arena, 195)).toBeCloseTo((1 - math.cos(math.pi * 0.75)) / 2)
		expect(Centerline.straightness(arena, Centerline.length(arena) - 5)).toBeCloseTo(
			(1 - math.cos(math.pi * 0.25)) / 2
		)
	end)
end)
