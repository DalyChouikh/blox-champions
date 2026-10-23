--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it = JestGlobals.describe, JestGlobals.it

local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local Vectors = require(ReplicatedStorage.Shared.Util.Vectors)

describe("Vectors", function()
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
