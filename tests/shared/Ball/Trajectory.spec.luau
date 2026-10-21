--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local Trajectory = require(ReplicatedStorage.Shared.Ball.Trajectory)

local SIMPLE_GRAVITY = Vector3.new(0, -10, 0)
local FACING_X = CFrame.lookAt(Vector3.new(10, 0, 0), Vector3.new(11, 0, 0))
local FACING_UP = CFrame.lookAt(Vector3.new(0, 10, 0), Vector3.new(0, 11, 0), Vector3.zAxis)

describe("Trajectory.positionAt", function()
	it("follows constant gravity", function()
		local p = Trajectory.positionAt(Vector3.new(0, 10, 0), Vector3.new(10, 20, 0), Fixtures.GRAVITY, 0.5)
		expect(p.X).toBeCloseTo(5)
		expect(p.Y).toBeCloseTo(-4.525)
		expect(p.Z).toBeCloseTo(0)
	end)
end)

describe("Trajectory.forwardCrossingTime", function()
	it("solves a straight path when gravity runs along the plane", function()
		expect(Trajectory.forwardCrossingTime(Vector3.zero, Vector3.new(20, 0, 0), Fixtures.GRAVITY, FACING_X, 2)).toBeCloseTo(
			0.5
		)
	end)

	it("returns the forward crossing of an arc, not the later backward one", function()
		expect(Trajectory.forwardCrossingTime(Vector3.zero, Vector3.new(0, 30, 0), SIMPLE_GRAVITY, FACING_UP, 10)).toBeCloseTo(
			3 - math.sqrt(7)
		)
	end)

	it("ignores crossings against the facing, in the past, or after maxTime", function()
		expect(Trajectory.forwardCrossingTime(Vector3.new(0, 20, 0), Vector3.zero, SIMPLE_GRAVITY, FACING_UP, 5)).toBeNil()
		expect(
			Trajectory.forwardCrossingTime(Vector3.new(12, 0, 0), Vector3.new(5, 0, 0), Fixtures.GRAVITY, FACING_X, 5)
		).toBeNil()
		expect(Trajectory.forwardCrossingTime(Vector3.zero, Vector3.new(20, 0, 0), Fixtures.GRAVITY, FACING_X, 0.4)).toBeNil()
	end)
end)
