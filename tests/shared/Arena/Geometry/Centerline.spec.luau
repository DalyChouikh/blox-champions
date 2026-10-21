--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Centerline = require(ReplicatedStorage.Shared.Arena.Geometry.Centerline)
local Config = require(ReplicatedStorage.Shared.Config)

local arena = Config.defaults().Arena

local function near(actual: Vector3, expected: Vector3)
	expect((actual - expected).Magnitude).toBeLessThan(1e-3)
end

describe("Centerline", function()
	it("is two straights and two half circles long", function()
		expect(Centerline.length(arena)).toBeCloseTo(2 * 160 + 2 * math.pi * 60, 4)
	end)

	it("places the gates at the four corners in counter-clockwise travel order, outer wall on the right", function()
		local expected = {
			{ Vector3.new(80, 0, -60), Vector3.new(-1, 0, 0) },
			{ Vector3.new(-80, 0, -60), Vector3.new(-1, 0, 0) },
			{ Vector3.new(-80, 0, 60), Vector3.new(1, 0, 0) },
			{ Vector3.new(80, 0, 60), Vector3.new(1, 0, 0) },
		}
		for gate, pair in expected do
			local frame = Centerline.frameAt(arena, Centerline.gateDistance(arena, gate))
			near(frame.Position, pair[1])
			near(frame.LookVector, pair[2])
		end
		near(Centerline.frameAt(arena, 0).RightVector, Vector3.new(0, 0, -1))
		near(Centerline.frameAt(arena, Centerline.gateDistance(arena, 3)).RightVector, Vector3.new(0, 0, 1))
	end)

	it("turns left through each curved end, closes the loop, and offsets across the track", function()
		local apex = Centerline.frameAt(arena, 160 + 30 * math.pi)
		near(apex.Position, Vector3.new(-140, 0, 0))
		near(apex.LookVector, Vector3.new(0, 0, 1))
		near(apex.RightVector, Vector3.new(-1, 0, 0))
		near(Centerline.frameAt(arena, Centerline.length(arena)).Position, Centerline.frameAt(arena, 0).Position)
		near(Centerline.at(arena, 80, 0, 20).Position, Vector3.new(0, 20, -38))
	end)

	it("puts stations at most segmentLength apart around the whole loop, one on every gate", function()
		local stations = Centerline.stations(arena)
		expect(#stations).toBe(176)
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
		expect(stations[41]).toBe(curve[1])
		expect(stations[42]).toBe(curve[2])
	end)

	it("blends the straights' step into the curves' flat floor around each corner", function()
		expect(Centerline.stepBlend(arena, 80)).toBe(1)
		expect(Centerline.stepBlend(arena, 160 + 30 * math.pi)).toBe(0)
		expect(Centerline.stepBlend(arena, 160)).toBeCloseTo(0.5)
		expect(Centerline.stepBlend(arena, 150)).toBeCloseTo(1)
		expect(Centerline.stepBlend(arena, 170)).toBeCloseTo(0)
		expect(Centerline.stepBlend(arena, 155)).toBeCloseTo((1 - math.cos(math.pi * 0.75)) / 2)
		expect(Centerline.stepBlend(arena, Centerline.length(arena) - 5)).toBeCloseTo(
			(1 - math.cos(math.pi * 0.25)) / 2
		)
	end)
end)
