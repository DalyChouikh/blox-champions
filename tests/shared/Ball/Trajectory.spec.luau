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

-- A throw that comes down where the crosshair points (#313, the owner: Q148, Q151). Worked examples at 50 studs/s
-- under 24 studs/s^2, computed apart from the code (a brute-force scan for the earliest time the ball can be there,
-- s58\worked313b.py): 100 studs out on the level the two arcs leave at tan 3/4 and 4/3, so the flatter one is (0.8,
-- 0.6) and covers the 100 studs at 40 studs/s in 2.5 s.
describe("Trajectory.launch", function()
	local GRAVITY = Vector3.new(0, -24, 0)
	local SPEED = 50

	it("leaves on the flatter of the two arcs through the target, and tells how long it takes to get there", function()
		local direction, time, reaches = Trajectory.launch(SPEED, Vector3.zero, Vector3.new(100, 0, 0), GRAVITY)
		Fixtures.expectNear(direction, Vector3.new(0.8, 0.6, 0), 1e-6)
		expect(time).toBeCloseTo(2.5, 6)
		expect(reaches).toBe(true)
		-- From anywhere: only the offset counts.
		local from = Vector3.new(7, -3, 11)
		local moved, movedTime = Trajectory.launch(SPEED, from, from + Vector3.new(0, 0, -100), GRAVITY)
		Fixtures.expectNear(moved, Vector3.new(0, 0.6, -0.8), 1e-6)
		expect(movedTime).toBeCloseTo(2.5, 6)
	end)

	it("pulls the way gravity does, whatever way that is", function()
		local direction = Trajectory.launch(SPEED, Vector3.zero, Vector3.new(0, 100, 0), Vector3.new(-24, 0, 0))
		Fixtures.expectNear(direction, Vector3.new(0.6, 0.8, 0), 1e-6)
	end)

	-- Out of reach (level, past v^2 / g = 104 studs; or high above), the arc that needs the least speed to get there:
	-- halfway between straight up and the line to the target, tan = (rise + distance) / across.
	it(
		"leaves on the arc that needs the least speed when the target is out of reach, and says it falls short",
		function()
			local level, _, reaches = Trajectory.launch(SPEED, Vector3.zero, Vector3.new(200, 0, 0), GRAVITY)
			Fixtures.expectNear(level, Vector3.new(1, 1, 0).Unit, 1e-6)
			expect(reaches).toBe(false)
			local high, _, highReaches = Trajectory.launch(SPEED, Vector3.zero, Vector3.new(200, 150, 0), GRAVITY)
			Fixtures.expectNear(high, Vector3.new(1, 2, 0).Unit, 1e-6)
			expect(highReaches).toBe(false)
		end
	)

	it("throws straight up or down at a target right above or below", function()
		local up, upTime, upReaches = Trajectory.launch(SPEED, Vector3.zero, Vector3.new(0, 20, 0), GRAVITY)
		Fixtures.expectNear(up, Vector3.yAxis, 1e-6)
		expect(upTime).toBeCloseTo(0.448215, 5)
		expect(upReaches).toBe(true)
		-- Too high (it tops out at 50^2 / 48 = 52 studs): the climb to its top, 50 / 24 s, until it stops rising.
		local _, climb, tooHigh = Trajectory.launch(SPEED, Vector3.zero, Vector3.new(0, 100, 0), GRAVITY)
		expect(climb).toBeCloseTo(2.083333, 5)
		expect(tooHigh).toBe(false)
		local down, downTime, downReaches = Trajectory.launch(SPEED, Vector3.zero, Vector3.new(0, -20, 0), GRAVITY)
		Fixtures.expectNear(down, -Vector3.yAxis, 1e-6)
		expect(downTime).toBeCloseTo(0.367574, 5)
		expect(downReaches).toBe(true)
	end)

	it("goes straight at the target where nothing pulls", function()
		local direction, time, reaches = Trajectory.launch(SPEED, Vector3.zero, Vector3.new(0, 30, -40), Vector3.zero)
		Fixtures.expectNear(direction, Vector3.new(0, 0.6, -0.8), 1e-6)
		expect(time).toBeCloseTo(1, 6)
		expect(reaches).toBe(true)
	end)

	-- A target at the hand itself, with gravity or without: straight up (against gravity, or +Y with none), there at
	-- once.
	it("throws straight up at a target at the hand itself, and is there at once", function()
		local hand = Vector3.new(4, 2, -3)
		for _, gravity in { GRAVITY, Vector3.zero } do
			local direction, time, reaches = Trajectory.launch(SPEED, hand, hand, gravity)
			Fixtures.expectNear(direction, Vector3.yAxis, 1e-6)
			expect(time).toBe(0)
			expect(reaches).toBe(true)
		end
	end)
end)

-- The thrower's velocity rides in the ball (Throw's inheritCarrierVelocity): the launch at SPEED from the hand plus
-- that carry still meets the target. Worked: sideways (0, 0, 15) to (60, 0, 0) meets it at 1.33560 s leaving at
-- (44.9236, 16.0272, 0); along (10, 0, 0) to (100, 0, 0) at 1.81865 s leaving at (54.9858, 21.8238, 0).
describe("Trajectory.toward", function()
	local GRAVITY = Vector3.new(0, -24, 0)
	local SPEED = 50

	it("meets the target with the thrower's velocity in the ball, at the speed from the hand", function()
		local sideways = Vector3.new(0, 0, 15)
		local velocity, reaches, time = Trajectory.toward(SPEED, Vector3.zero, Vector3.new(60, 0, 0), sideways, GRAVITY)
		Fixtures.expectNear(velocity, Vector3.new(44.9236, 16.0272, 0), 1e-3)
		expect((velocity - sideways).Magnitude).toBeCloseTo(SPEED, 3)
		expect(reaches).toBe(true)
		-- How long the flight takes to get there (#342: a throw is exact only that soon, Throw.aimed).
		expect(time).toBeCloseTo(1.33560, 4)
		Fixtures.expectNear(
			Trajectory.positionAt(Vector3.zero, velocity, GRAVITY, 1.33560),
			Vector3.new(60, 0, 0),
			1e-2
		)
		local along = Vector3.new(10, 0, 0)
		local ahead = Trajectory.toward(SPEED, Vector3.zero, Vector3.new(100, 0, 0), along, GRAVITY)
		Fixtures.expectNear(ahead, Vector3.new(54.9858, 21.8238, 0), 1e-3)
	end)

	it("is the plain launch for a thrower standing still", function()
		local velocity, reaches, time =
			Trajectory.toward(SPEED, Vector3.zero, Vector3.new(100, 0, 0), Vector3.zero, GRAVITY)
		-- Within a Vector3's float32 step at 30 (1.9e-6), not the closed form's exactness.
		Fixtures.expectNear(velocity, Vector3.new(40, 30, 0), 1e-4)
		expect(reaches).toBe(true)
		expect(time).toBeCloseTo(2.5, 6)
		local _, short = Trajectory.toward(SPEED, Vector3.zero, Vector3.new(200, 0, 0), Vector3.zero, GRAVITY)
		expect(short).toBe(false)
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
