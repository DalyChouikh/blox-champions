--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Crossing = require(ReplicatedStorage.Shared.Rules.Crossing)

local FACING_X = CFrame.lookAt(Vector3.zero, Vector3.xAxis)

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

describe("Crossing.throughRectangle", function()
	local rect: Crossing.Rectangle = { frame = FACING_X, width = 10, height = 6 }

	it("returns where along the segment it crosses forward inside the rectangle", function()
		expect(Crossing.throughRectangle(rect, v(-1, 0, 0), v(3, 0, 0))).toBeCloseTo(0.25)
	end)

	it("ignores backward crossings and segments that stay on one side", function()
		expect(Crossing.throughRectangle(rect, v(1, 0, 0), v(-1, 0, 0))).toBeNil()
		expect(Crossing.throughRectangle(rect, v(-3, 0, 0), v(-1, 0, 0))).toBeNil()
		expect(Crossing.throughRectangle(rect, v(1, 0, 0), v(2, 0, 0))).toBeNil()
	end)

	it("ignores crossings outside the rectangle and includes its edges", function()
		expect(Crossing.throughRectangle(rect, v(-1, 0, 6), v(1, 0, 6))).toBeNil()
		expect(Crossing.throughRectangle(rect, v(-1, 4, 0), v(1, 4, 0))).toBeNil()
		expect(Crossing.throughRectangle(rect, v(-1, 3, 5), v(1, 3, 5))).toBeCloseTo(0.5)
	end)

	it("counts a ball that stops exactly on the plane once, not again when it moves on", function()
		expect(Crossing.throughRectangle(rect, v(-1, 0, 0), v(0, 0, 0))).toBe(1)
		expect(Crossing.throughRectangle(rect, v(0, 0, 0), v(1, 0, 0))).toBeNil()
	end)

	it("uses the frame's position and facing", function()
		local facingNegativeZ: Crossing.Rectangle =
			{ frame = CFrame.lookAt(v(10, 5, 0), v(10, 5, -1)), width = 2, height = 2 }
		expect(Crossing.throughRectangle(facingNegativeZ, v(10, 5, 1), v(10, 5, -1))).toBeCloseTo(0.5)
		expect(Crossing.throughRectangle(facingNegativeZ, v(10, 5, -1), v(10, 5, 1))).toBeNil()
	end)
end)

describe("Crossing.throughDisc", function()
	it("counts forward crossings within the radius only", function()
		local disc: Crossing.Disc = { frame = FACING_X, radius = 7 }
		expect(Crossing.throughDisc(disc, v(-1, 0, 6.9), v(1, 0, 6.9))).toBeCloseTo(0.5)
		expect(Crossing.throughDisc(disc, v(-1, 5, 5), v(1, 5, 5))).toBeNil()
		expect(Crossing.throughDisc(disc, v(1, 0, 0), v(-1, 0, 0))).toBeNil()
	end)
end)

describe("Crossing.withinDisc", function()
	it("measures distance from the disc's axis and ignores distance from its plane", function()
		local disc: Crossing.Disc = { frame = FACING_X, radius = 5 }
		expect(Crossing.withinDisc(disc, v(0, 3, 4))).toBe(true)
		expect(Crossing.withinDisc(disc, v(0, 4, 4))).toBe(false)
		expect(Crossing.withinDisc(disc, v(2, 3, 4))).toBe(true)
	end)
end)
