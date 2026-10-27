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

describe("Trajectory.crossingTimes", function()
	it("solves a straight path when gravity runs along the plane, either way through it", function()
		local first, second =
			Trajectory.crossingTimes(Vector3.zero, Vector3.new(20, 0, 0), Fixtures.GRAVITY, FACING_X, 2)
		expect(first).toBeCloseTo(0.5)
		expect(second).toBeNil()
		local back =
			Trajectory.crossingTimes(Vector3.new(20, 0, 0), Vector3.new(-20, 0, 0), Fixtures.GRAVITY, FACING_X, 2)
		expect(back).toBeCloseTo(0.5)
	end)

	it("returns both crossings of an arc, the earlier first, and one for an arc that only touches the plane", function()
		local first, second =
			Trajectory.crossingTimes(Vector3.zero, Vector3.new(0, 30, 0), SIMPLE_GRAVITY, FACING_UP, 10)
		expect(first).toBeCloseTo(3 - math.sqrt(7))
		expect(second).toBeCloseTo(3 + math.sqrt(7))
		-- Thrown up at 10 from 5 under the plane, it peaks exactly on it at t = 1.
		first, second =
			Trajectory.crossingTimes(Vector3.new(0, 5, 0), Vector3.new(0, 10, 0), SIMPLE_GRAVITY, FACING_UP, 10)
		expect(first).toBeCloseTo(1)
		expect(second).toBeNil()
	end)

	it("treats a ball already on the plane as having crossed it, as Crossing does", function()
		-- Moving straight away from it: none. Rising off it under gravity: only the fall back through it.
		local first, second =
			Trajectory.crossingTimes(Vector3.new(10, 0, 0), Vector3.new(20, 0, 0), Fixtures.GRAVITY, FACING_X, 2)
		expect(first).toBeNil()
		expect(second).toBeNil()
		first, second =
			Trajectory.crossingTimes(Vector3.new(0, 10, 0), Vector3.new(0, 5, 0), SIMPLE_GRAVITY, FACING_UP, 2)
		expect(first).toBeCloseTo(1)
		expect(second).toBeNil()
	end)

	it("meets a plane below a falling ball, and leaves out crossings in the past or after maxTime", function()
		local falling = Trajectory.crossingTimes(Vector3.new(0, 20, 0), Vector3.zero, SIMPLE_GRAVITY, FACING_UP, 5)
		expect(falling).toBeCloseTo(math.sqrt(2))
		local past =
			Trajectory.crossingTimes(Vector3.new(12, 0, 0), Vector3.new(5, 0, 0), Fixtures.GRAVITY, FACING_X, 5)
		expect(past).toBeNil()
		local late = Trajectory.crossingTimes(Vector3.zero, Vector3.new(20, 0, 0), Fixtures.GRAVITY, FACING_X, 0.4)
		expect(late).toBeNil()
		-- An arc whose second crossing comes after maxTime keeps only its first.
		local first, second =
			Trajectory.crossingTimes(Vector3.zero, Vector3.new(0, 30, 0), SIMPLE_GRAVITY, FACING_UP, 3)
		expect(first).toBeCloseTo(3 - math.sqrt(7))
		expect(second).toBeNil()
	end)
end)
