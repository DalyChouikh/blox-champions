--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local ChaseCamera = require(ReplicatedStorage.Shared.Camera.ChaseCamera)
local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)

local config = Config.defaults().Camera
local HARD_CAP = 140

-- A camera behind a skater on level ground facing -Z.
local function camera(): ChaseCamera.ChaseCamera
	return ChaseCamera.new(config, HARD_CAP, Vector3.yAxis, -Vector3.zAxis)
end

-- A step's input: still, on level ground, no swing-back, no Ball Focus, at rest.
local function target(overrides: { [string]: any }?): ChaseCamera.Target
	local value: ChaseCamera.Target = {
		up = Vector3.yAxis,
		travel = Vector3.zero,
		look = Vector2.zero,
		recenter = false,
		aimAt = nil,
		speed = 0,
	}
	local given: { [string]: any } = overrides or {}
	for key, override in given do
		(value :: any)[key] = override
	end
	return value
end

describe("ChaseCamera", function()
	it("looks along its heading, level, at fovBase", function()
		local chase = camera()
		Fixtures.expectNear(chase:lookVector(), Vector3.new(0, 0, -1))
		expect(chase.pitch).toBe(0)
		expect(chase.fov).toBe(70)
		expect(chase.idle).toBe(0)
	end)

	it("turns right and tips down with the look input, within the pitch limits", function()
		local chase = camera()
		chase:step(target({ look = Vector2.new(math.pi / 2, 0) }), 1 / 60)
		Fixtures.expectNear(chase.forward, Vector3.new(1, 0, 0))
		chase:step(target({ look = Vector2.new(0, math.rad(30)) }), 1 / 60)
		Fixtures.expectNear(chase:lookVector(), Vector3.new(math.cos(math.rad(30)), -0.5, 0))
		chase:step(target({ look = Vector2.new(0, math.rad(100)) }), 1 / 60)
		expect(chase.pitch).toBeCloseTo(math.rad(-70), 5)
		chase:step(target({ look = Vector2.new(0, -math.rad(500)) }), 1 / 60)
		expect(chase.pitch).toBeCloseTo(math.rad(60), 5)
	end)

	it("rolls toward the surface it rides, keeping its heading on that surface", function()
		local chase = camera()
		chase:step(target({ up = Vector3.xAxis }), 0.1)
		local rolled = 90 * (1 - math.exp(-0.8))
		expect(chase.up:Dot(Vector3.yAxis)).toBeCloseTo(math.cos(math.rad(rolled)), 3)
		chase:step(target({ up = Vector3.xAxis }), 10)
		Fixtures.expectNear(chase.up, Vector3.new(1, 0, 0))
		Fixtures.expectNear(chase.forward, Vector3.new(0, 0, -1))
	end)

	it("rolls over the top like a loop when its up turns upside down", function()
		local chase = camera()
		chase:step(target({ up = -Vector3.yAxis }), 10)
		Fixtures.expectNear(chase.up, Vector3.new(0, -1, 0))
		Fixtures.expectNear(chase.forward, Vector3.new(0, 0, 1))
	end)

	it("swings behind the travel once the look input rests, only when the device allows it", function()
		local moving = target({ travel = Vector3.new(50, 0, 0), recenter = true })
		local chase = camera()
		chase:step(moving, 0.4)
		Fixtures.expectNear(chase.forward, Vector3.new(0, 0, -1))
		chase:step(moving, 0.2)
		local swung = math.rad(90 * (1 - math.exp(-0.5)))
		expect(chase.forward:Dot(Vector3.xAxis)).toBeCloseTo(math.sin(swung), 3)

		-- With a mouse it never swings.
		local mouse = camera()
		mouse:step(target({ travel = Vector3.new(50, 0, 0) }), 2)
		Fixtures.expectNear(mouse.forward, Vector3.new(0, 0, -1))
		-- Nor behind a skater slower than recenterMinSpeed.
		local slow = camera()
		slow:step(target({ travel = Vector3.new(5, 0, 0), recenter = true }), 2)
		Fixtures.expectNear(slow.forward, Vector3.new(0, 0, -1))
		-- A look input rests the swing-back: the camera waits recenterDelay again.
		local looking = camera()
		looking:step(moving, 0.4)
		looking:step(target({ travel = Vector3.new(50, 0, 0), recenter = true, look = Vector2.new(0, 0.01) }), 0.2)
		Fixtures.expectNear(looking.forward, Vector3.new(0, 0, -1))
	end)

	it("turns toward the ball with Ball Focus, within the pitch limits", function()
		local chase = camera()
		chase:step(target({ aimAt = Vector3.new(1, 1, 0) }), 10)
		Fixtures.expectNear(chase.forward, Vector3.new(1, 0, 0))
		expect(chase.pitch).toBeCloseTo(math.rad(45), 3)

		local above = camera()
		above:step(target({ aimAt = Vector3.new(0, 1, 0) }), 10)
		Fixtures.expectNear(above.forward, Vector3.new(0, 0, -1))
		expect(above.pitch).toBeCloseTo(math.rad(60), 3)
	end)

	it("widens the field of view with speed toward hardCap", function()
		expect(ChaseCamera.targetFov(config, 0, HARD_CAP)).toBe(70)
		expect(ChaseCamera.targetFov(config, 70, HARD_CAP)).toBe(80)
		expect(ChaseCamera.targetFov(config, 140, HARD_CAP)).toBe(90)
		expect(ChaseCamera.targetFov(config, 300, HARD_CAP)).toBe(90)
		local chase = camera()
		chase:step(target({ speed = 140 }), 0.1)
		expect(chase.fov).toBeCloseTo(70 + 20 * (1 - math.exp(-0.6)), 3)
	end)

	it("pulls in in front of a hit, never closer than minDistance", function()
		expect(ChaseCamera.pullIn(config, 12, nil)).toBe(12)
		expect(ChaseCamera.pullIn(config, 12, 8)).toBe(7.5)
		expect(ChaseCamera.pullIn(config, 12, 1)).toBe(2)
	end)

	it("resets behind a facing, level", function()
		local chase = camera()
		chase:step(target({ look = Vector2.new(1, 0.5) }), 1 / 60)
		chase:reset(Vector3.yAxis, Vector3.xAxis)
		Fixtures.expectNear(chase.forward, Vector3.new(1, 0, 0))
		expect(chase.pitch).toBe(0)
		expect(chase.idle).toBe(0)
	end)
end)
