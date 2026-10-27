--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local Vectors = require(ReplicatedStorage.Shared.Util.Vectors)

-- Measured in Play (#234): a smoothed ground normal just under unit length, 1.3e-4 rad from the glass's.
local SHORT = Vector3.new(0, 0.000130117856, -0.999999881)
local GLASS = Vector3.new(0, 0, -1)

describe("Vectors", function()
	it("measures the angle between two vectors exactly, even a tiny one", function()
		-- atan2 of |a × b| = 1.30117856e-4 over a · b = 0.999999881. The arccosine of that dot product reads 4.88e-4.
		expect(Vectors.angleBetween(SHORT, GLASS)).toBeCloseTo(1.30117856e-4, 9)
		expect(Vectors.angleBetween(Vector3.xAxis, Vector3.new(0, 2, 0))).toBeCloseTo(math.pi / 2, 6)
	end)

	it("turns a vector toward another, landing on it when the gap is within the turn, however small", function()
		local turned = Vectors.rotateToward(Vector3.xAxis, Vector3.zAxis, math.pi / 4, Vector3.yAxis)
		Fixtures.expectNear(turned, Vector3.new(math.sqrt(0.5), 0, math.sqrt(0.5)))
		expect(Vectors.rotateToward(SHORT, GLASS, 2e-4, Vector3.xAxis) == GLASS).toBe(true)
	end)

	it("shortens a vector to a length, keeping its direction, and leaves a shorter one alone", function()
		Fixtures.expectNear(Vectors.clampMagnitude(Vector3.new(0, 0, -10000), 168), Vector3.new(0, 0, -168))
		Fixtures.expectNear(Vectors.clampMagnitude(Vector3.new(3, 4, 0), 10), Vector3.new(3, 4, 0))
		Fixtures.expectNear(Vectors.clampMagnitude(Vector3.zero, 10), Vector3.zero)
	end)

	it("rotates a vector about an axis, right-handed", function()
		Fixtures.expectNear(Vectors.rotateAbout(Vector3.xAxis, Vector3.yAxis, math.pi / 2), Vector3.new(0, 0, -1))
		Fixtures.expectNear(Vectors.rotateAbout(-Vector3.zAxis, Vector3.yAxis, -math.pi / 2), Vector3.new(1, 0, 0))
	end)
end)
