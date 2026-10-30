--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local ChaseCamera = require(ReplicatedStorage.Shared.Camera.ChaseCamera)
local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)

local config = Config.defaults().Camera
local HARD_CAP = 140
local DT = 1 / 60

-- A camera behind a skater on level ground facing -Z.
local function camera(): ChaseCamera.ChaseCamera
	return ChaseCamera.new(config, HARD_CAP, Vector3.yAxis, -Vector3.zAxis)
end

-- A step's input: still, on level ground, no swing-back, no Ball Focus, at rest.
local function target(overrides: { [string]: any }?): ChaseCamera.Target
	local value: ChaseCamera.Target = {
		up = Vector3.yAxis,
		behind = Vector3.zero,
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
		-- The look is a rate, in radians per second: one step turns it for that step's dt.
		local chase = camera()
		chase:step(target({ look = Vector2.new(math.pi / 2, 0) / DT }), DT)
		Fixtures.expectNear(chase.forward, Vector3.new(1, 0, 0))
		chase:step(target({ look = Vector2.new(0, math.rad(30)) / DT }), DT)
		Fixtures.expectNear(chase:lookVector(), Vector3.new(math.cos(math.rad(30)), -0.5, 0))
		chase:step(target({ look = Vector2.new(0, math.rad(100)) / DT }), DT)
		expect(chase.pitch).toBeCloseTo(math.rad(-70), 5)
		chase:step(target({ look = Vector2.new(0, -math.rad(500)) / DT }), DT)
		expect(chase.pitch).toBeCloseTo(math.rad(60), 5)
	end)

	-- The owner (#223): the view leans with the surface only up to maxTiltDeg from world up, 30°, picked from
	-- screenshots, so a wall never stands the floor up on screen.
	it("rolls toward the surface it rides up to maxTiltDeg, keeping its heading on the plane of its up", function()
		local chase = camera()
		chase:step(target({ up = Vector3.xAxis }), 0.1)
		-- Toward the limit, not the wall: 30° × (1 − e^(−8 × 0.1)) = 16.52°.
		local rolled = 30 * (1 - math.exp(-0.8))
		expect(chase.up:Dot(Vector3.yAxis)).toBeCloseTo(math.cos(math.rad(rolled)), 3)
		chase:step(target({ up = Vector3.xAxis }), 10)
		Fixtures.expectNear(chase.up, Vector3.new(0.5, math.sqrt(3) / 2, 0))
		Fixtures.expectNear(chase.forward, Vector3.new(0, 0, -1))
		-- A bank gentler than the limit, 20°, it follows all the way.
		local bank = Vector3.new(math.sin(math.rad(20)), math.cos(math.rad(20)), 0)
		chase:step(target({ up = bank }), 10)
		Fixtures.expectNear(chase.up, bank)
		-- Another limit leans that far: 45° on the wall.
		local settings = Fixtures.config({ Camera = { maxTiltDeg = 45 } }).Camera
		local wide = ChaseCamera.new(settings, HARD_CAP, Vector3.yAxis, -Vector3.zAxis)
		wide:step(target({ up = Vector3.xAxis }), 10)
		Fixtures.expectNear(wide.up, Vector3.new(math.sqrt(0.5), math.sqrt(0.5), 0))
	end)

	it("never leans past maxTiltDeg, on any surface, over a lip or upside down", function()
		-- Surfaces all the way round, from the floor over a wall to a ceiling and back, a few frames on each.
		local chase = camera()
		for step = 0, 24 do
			local angle = math.rad(15 * step)
			chase:step(target({ up = Vector3.new(math.sin(angle), math.cos(angle), 0) }), 0.05)
			expect(math.deg(math.atan2(chase.up:Cross(Vector3.yAxis).Magnitude, chase.up.Y))).toBeLessThan(30 + 1e-3)
		end
		-- A lip 135° from world up, overhanging toward −X: the view leans the limit toward it.
		local lip = camera()
		lip:step(target({ up = Vector3.new(-1, -1, 0).Unit }), 10)
		Fixtures.expectNear(lip.up, Vector3.new(-0.5, math.sqrt(3) / 2, 0))
		-- Straight down no side is nearer than another: it keeps the lean it has.
		lip:step(target({ up = -Vector3.yAxis }), 10)
		Fixtures.expectNear(lip.up, Vector3.new(-0.5, math.sqrt(3) / 2, 0))
		local level = camera()
		level:step(target({ up = -Vector3.yAxis }), 10)
		Fixtures.expectNear(level.up, Vector3.yAxis)
		Fixtures.expectNear(level.forward, Vector3.new(0, 0, -1))
	end)

	it("rolls back level at rollResponse once the surface flattens", function()
		local chase = camera()
		chase:step(target({ up = Vector3.xAxis }), 10)
		chase:step(target(), 0.1)
		-- 30° × e^(−8 × 0.1) = 13.48° left.
		expect(chase.up:Dot(Vector3.yAxis)).toBeCloseTo(math.cos(math.rad(30 * math.exp(-0.8))), 4)
		chase:step(target(), 10)
		Fixtures.expectNear(chase.up, Vector3.yAxis)
	end)

	it("swings behind the way it is given once the look input rests, only when the device allows it", function()
		local moving = target({ behind = Vector3.new(50, 0, 0), recenter = true })
		local chase = camera()
		chase:step(moving, 0.4)
		Fixtures.expectNear(chase.forward, Vector3.new(0, 0, -1))
		chase:step(moving, 0.2)
		local swung = math.rad(90 * (1 - math.exp(-0.5)))
		expect(chase.forward:Dot(Vector3.xAxis)).toBeCloseTo(math.sin(swung), 3)

		-- With a mouse it never swings.
		local mouse = camera()
		mouse:step(target({ behind = Vector3.new(50, 0, 0) }), 2)
		Fixtures.expectNear(mouse.forward, Vector3.new(0, 0, -1))
		-- Nor behind a skater slower than recenterMinSpeed.
		local slow = camera()
		slow:step(target({ behind = Vector3.new(5, 0, 0), recenter = true }), 2)
		Fixtures.expectNear(slow.forward, Vector3.new(0, 0, -1))
		-- A look input rests the swing-back: the camera waits recenterDelay again.
		local looking = camera()
		looking:step(moving, 0.4)
		looking:step(target({ behind = Vector3.new(50, 0, 0), recenter = true, look = Vector2.new(0, 0.01) }), 0.2)
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

	-- The owner's trial A3 (#276, Q53): farther and higher looking down, closer looking up, down to the feet; the
	-- rows worked out independently (model276.py).
	it("frames by its pitch: how far behind its focus, and the focus's height above the root", function()
		local rows: { { number } } = {
			{ -70, 22, 5 },
			{ -55, 22, 5 },
			{ -35, 19, 5 },
			{ -15, 15, 5 },
			{ 0, 12, 5 },
			{ 2, 11.733333, 5 },
			{ 10, 10.666667, 5 },
			{ 22.5, 7.5, 3.25 },
			-- Where the skater starts to fade (fade.seen, 4).
			{ 33.75, 4, 0.75 },
			{ 40, 2.333333, -0.5 },
			{ 45, 1, -1.5 },
			{ 60, 1, -1.5 },
		}
		for _, row in rows do
			local distance, height = ChaseCamera.framing(config, math.rad(row[1]))
			expect(distance).toBeCloseTo(row[2], 5)
			expect(height).toBeCloseTo(row[3], 5)
		end
		-- One point holds at every pitch.
		local one = Fixtures.config({ Camera = { framing = { { pitchDeg = 10, distance = 9, height = 2 } } } }).Camera
		for _, degrees in { -70, 10, 60 } do
			local distance, height = ChaseCamera.framing(one, math.rad(degrees))
			expect(distance).toBe(9)
			expect(height).toBe(2)
		end
	end)

	-- Roller Champions' skater turns see-through and vanishes as its camera slides in (Video 18); the owner's trial
	-- A3 (#276, Q53).
	it("fades the skater as the camera closes in on its focus: whole at fade.seen, gone at fade.gone", function()
		local rows: { { number } } =
			{ { 12, 0 }, { 4, 0 }, { 3, 0.4 }, { 2.75, 0.5 }, { 2, 0.8 }, { 1.5, 1 }, { 0, 1 } }
		for _, row in rows do
			expect(ChaseCamera.fade(config, row[1])).toBeCloseTo(row[2], 5)
		end
	end)

	it("pulls in in front of a hit, never past it", function()
		expect(ChaseCamera.pullIn(config, 12, nil)).toBe(12)
		expect(ChaseCamera.pullIn(config, 12, 8)).toBe(7.5)
		expect(ChaseCamera.pullIn(config, 12, 1)).toBe(0.5)
		-- A hit nearer than collisionMargin: the camera stays at its focus.
		expect(ChaseCamera.pullIn(config, 12, 0.2)).toBe(0)
	end)

	it("rests only while Ball Focus is not turning it", function()
		local chase = camera()
		chase:step(target({ aimAt = Vector3.new(-1, 0, 0) }), 10)
		Fixtures.expectNear(chase.forward, Vector3.new(-1, 0, 0))
		expect(chase.idle).toBe(0)
		-- Let go on a gamepad: it stays where it turned until the look has rested recenterDelay.
		chase:step(target({ behind = Vector3.new(50, 0, 0), recenter = true }), 0.4)
		Fixtures.expectNear(chase.forward, Vector3.new(-1, 0, 0))
	end)

	it("resets behind a facing, level, at fovBase", function()
		local chase = camera()
		chase:step(target({ look = Vector2.new(1, 0.5) / DT, speed = 140 }), 10)
		expect(chase.fov).toBeCloseTo(90, 3)
		chase:reset(Vector3.yAxis, Vector3.xAxis)
		Fixtures.expectNear(chase.forward, Vector3.new(1, 0, 0))
		expect(chase.pitch).toBe(0)
		expect(chase.idle).toBe(0)
		expect(chase.fov).toBe(70)
		-- A new character on a wall: the view starts leaning only the limit toward it.
		chase:reset(Vector3.xAxis, -Vector3.zAxis)
		Fixtures.expectNear(chase.up, Vector3.new(0.5, math.sqrt(3) / 2, 0))
		Fixtures.expectNear(chase.forward, Vector3.new(0, 0, -1))
		-- Under a surface facing straight down no side is nearer: it starts level.
		chase:reset(-Vector3.yAxis, -Vector3.zAxis)
		Fixtures.expectNear(chase.up, Vector3.yAxis)
		Fixtures.expectNear(chase.forward, Vector3.new(0, 0, -1))
	end)
end)
