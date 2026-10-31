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

-- A floor at y 0 for Trajectory.path: where a chord from one point to the next first reaches it, else nil.
local function floor(from: Vector3, to: Vector3): Vector3?
	if to.Y >= 0 then
		return nil
	end
	return from:Lerp(to, from.Y / (from.Y - to.Y))
end

local function clear(_from: Vector3, _to: Vector3): Vector3?
	return nil
end

-- The thrower's predicted arc (#313). Worked example: from (0, 5, 0) at (40, 0, 0) under (0, -100, 0), a point every
-- 4 studs of the launch speed is every 0.1 s: (4, 4.5, 0), (8, 3, 0), (12, 0.5, 0), then (16, -3, 0) lies under the
-- floor, which the chord from (12, 0.5, 0) meets 0.5 / 3.5 of the way along: x = 12 + 4/7.
describe("Trajectory.path", function()
	local GRAVITY = Vector3.new(0, -100, 0)
	local START, VELOCITY = Vector3.new(0, 5, 0), Vector3.new(40, 0, 0)

	it("puts a point every spacing studs of the launch speed, ending where the ball first touches", function()
		local points: { Vector3 } = {}
		local count, touched = Trajectory.path(START, VELOCITY, GRAVITY, 4, 10, floor, points)
		expect(count).toBe(5)
		expect(touched).toBe(true)
		Fixtures.expectNear(points[1], START)
		Fixtures.expectNear(points[2], Vector3.new(4, 4.5, 0))
		Fixtures.expectNear(points[3], Vector3.new(8, 3, 0))
		Fixtures.expectNear(points[4], Vector3.new(12, 0.5, 0))
		Fixtures.expectNear(points[5], Vector3.new(12 + 4 / 7, 0, 0))
	end)

	it("stops at maxCount points with nothing in the way, and fills the caller's list in place", function()
		local points: { Vector3 } = { Vector3.one, Vector3.one, Vector3.one, Vector3.one }
		local count, touched = Trajectory.path(START, VELOCITY, GRAVITY, 4, 3, clear, points)
		expect(count).toBe(3)
		expect(touched).toBe(false)
		Fixtures.expectNear(points[3], Vector3.new(8, 3, 0))
		-- Past the count, the list keeps what it held.
		Fixtures.expectNear(points[4], Vector3.one)
	end)

	it("casts each chord from the point before it, in order", function()
		local chords: { { Vector3 } } = {}
		local function record(from: Vector3, to: Vector3): Vector3?
			table.insert(chords, { from, to })
			return nil
		end
		Trajectory.path(START, VELOCITY, GRAVITY, 4, 3, record, {})
		expect(#chords).toBe(2)
		Fixtures.expectNear(chords[1][1], START)
		Fixtures.expectNear(chords[1][2], Vector3.new(4, 4.5, 0))
		Fixtures.expectNear(chords[2][1], Vector3.new(4, 4.5, 0))
		Fixtures.expectNear(chords[2][2], Vector3.new(8, 3, 0))
	end)

	it("draws no path for a ball that is not moving", function()
		local count, touched = Trajectory.path(START, Vector3.zero, GRAVITY, 4, 10, floor, {})
		expect(count).toBe(0)
		expect(touched).toBe(false)
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
