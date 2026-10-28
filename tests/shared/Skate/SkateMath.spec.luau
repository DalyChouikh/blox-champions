--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local SkateMath = require(ReplicatedStorage.Shared.Skate.SkateMath)
local Types = require(ReplicatedStorage.Shared.Skate.Types)
local Vectors = require(ReplicatedStorage.Shared.Util.Vectors)

-- Expected values come from a reference model of the formulas in the Phase 5 plan's decision 6; each comment shows
-- how to check one by hand.
local movement = Config.defaults().Movement
local FLAT = Vector3.yAxis
-- A 20° surface falling toward -Z, and the way down it: well under wallAngle, so gravity pulls along it in full.
local SLOPE_ANGLE = math.rad(20)
local SLOPE = Vector3.new(0, math.cos(SLOPE_ANGLE), -math.sin(SLOPE_ANGLE))
local DOWNHILL = Vector3.new(0, -math.sin(SLOPE_ANGLE), -math.cos(SLOPE_ANGLE))

local function input(overrides: { [string]: any }?): Types.SkateInput
	local record: Types.SkateInput = {
		move = Vector3.zero,
		pump = false,
		brake = false,
		jump = false,
		jumpHeld = false,
		draftAccel = 0,
		knockedDown = false,
		diving = false,
	}
	local changes: { [string]: any } = overrides or {}
	for key, value in changes do
		(record :: any)[key] = value
	end
	return record
end

local function ground(normal: Vector3?, distance: number?, hit: boolean?): Types.Ground
	return {
		hit = if hit == nil then true else hit,
		normal = normal or FLAT,
		distance = distance or movement.hoverHeight,
	}
end

local function skater(velocity: Vector3): SkateMath.Skater
	local s = SkateMath.new(movement, Fixtures.GRAVITY)
	s.velocity = velocity
	return s
end

describe("SkateMath on the ground", function()
	it("pushes off toward the stick and rolls against friction and drag", function()
		local s = skater(Vector3.zero)
		s:step(input({ move = -Vector3.zAxis }), ground(), 0.1)
		-- 30 × 0.1 = 3, then 3 − (4 + 0.02 × 3) × 0.1
		Fixtures.expectNear(s.velocity, Vector3.new(0, 0, -2.594))
		expect(s.mode).toBe("Grounded")
	end)

	it("coasts without input, slowed by rolling friction, air drag and coastDecel", function()
		local s = skater(Vector3.new(0, 0, -60))
		s:step(input(), ground(), 0.1)
		Fixtures.expectNear(s.velocity, Vector3.new(0, 0, -58.73)) -- 60 − (4 + 7.5 + 1.2) × 0.1
	end)

	-- The owner (#215): a skater who presses nothing stops from cruise (72 km/h) in about 5 s on flat ground.
	it("stops from cruise in about 5 s on flat ground with nothing pressed", function()
		local s = skater(Vector3.new(0, 0, -movement.cruiseSpeed))
		local steps = 0
		while s.velocity.Magnitude > 0 and steps < 600 do
			s:step(input(), ground(), 1 / 60)
			steps += 1
		end
		-- dv/dt = −(4 + 7.5 + 0.02 v): 50 × ln(1 + 1.2 / 11.5) = 4.96 s
		expect(steps / 60).toBeCloseTo(4.96, 1)
	end)

	it("strides only up to cruiseSpeed and settles there", function()
		local forward = input({ move = -Vector3.zAxis })
		local atCruise = skater(Vector3.new(0, 0, -60))
		atCruise:step(forward, ground(), 0.1)
		Fixtures.expectNear(atCruise.velocity, Vector3.new(0, 0, -59.48)) -- no push at cruiseSpeed: it coasts
		local s = skater(Vector3.zero)
		for _ = 1, 600 do
			s:step(forward, ground(), 1 / 60)
		end
		for _ = 1, 120 do
			s:step(forward, ground(), 1 / 60)
			-- The reference model stays between 59.91 and 60.41.
			expect(s.velocity.Magnitude > 59.5 and s.velocity.Magnitude < 60.5).toBe(true)
		end
	end)

	it("speeds up downhill by gravity's pull along the surface", function()
		local s = skater(DOWNHILL * 10)
		s:step(input(), ground(SLOPE), 0.1)
		-- + 196.2 × sin 20° × 0.1, then friction, drag and coastDecel (nothing is pressed)
		Fixtures.expectNear(s.velocity, DOWNHILL * 15.5270)
	end)

	it("scales speeding up down between softCap and hardCap", function()
		local s = skater(DOWNHILL * 115)
		s:step(input(), ground(SLOPE), 0.01)
		-- 67.10 × (121 − 115)/(121 − 90) = 12.99 studs/s², then friction, drag and coastDecel, then the bleed:
		-- 90 + 24.992 × e^−0.05
		expect(s.velocity.Magnitude).toBeCloseTo(113.7730, 3)
	end)

	-- Roller Champions (#214): a skater whipped to 144 km/h was back near 110 within about a second.
	it("bleeds speed past softCap off, the further over the faster, and never exceeds hardCap", function()
		local function after(speed: number): number
			local s = skater(Vector3.new(0, 0, -speed))
			s:step(input(), ground(), 0.1)
			return s.velocity.Magnitude
		end
		-- Nothing is pressed: 120 − (4 + 7.5 + 2.4) × 0.1 = 118.61, then 90 + 28.61 × e^−0.5
		expect(after(120)).toBeCloseTo(107.3528, 3)
		expect(after(100)).toBeCloseTo(95.2465, 3) -- 98.65, then 90 + 8.65 × e^−0.5
		expect(after(80)).toBeCloseTo(78.69, 3) -- under softCap: friction, drag and coastDecel only
		expect(after(150)).toBeCloseTo(121, 3) -- 125.51 after the bleed, then hardCap
	end)

	it("turns toward the stick at a rate that shrinks with speed", function()
		local function turned(speed: number): number
			local s = skater(Vector3.new(0, 0, -speed))
			s:step(input({ move = Vector3.xAxis }), ground(), 0.1)
			return math.atan2(s.velocity.X, -s.velocity.Z)
		end
		expect(turned(70)).toBeCloseTo(0.2554, 4) -- lerp(4.0, 1.5, 70/121) × 0.1
		expect(turned(121)).toBeCloseTo(0.15, 4)
		local still = skater(Vector3.zero)
		still:step(input({ move = Vector3.xAxis }), ground(), 0.1)
		Fixtures.expectNear(still.velocity, Vector3.new(2.594, 0, 0)) -- from rest it faces the stick at once
	end)

	it("brakes to a stop without reversing", function()
		local s = skater(Vector3.new(0, 0, -60))
		s:step(input({ brake = true }), ground(), 0.1)
		Fixtures.expectNear(s.velocity, Vector3.new(0, 0, -47.48)) -- 59.48 − 120 × 0.1
		local slow = skater(Vector3.new(0, 0, -5))
		slow:step(input({ brake = true }), ground(), 0.1)
		Fixtures.expectNear(slow.velocity, Vector3.zero)
	end)

	it("tiptoes: braking with the stick held moves exactly at up to tiptoeSpeed", function()
		local s = skater(Vector3.new(0, 0, -60))
		for _ = 1, 60 do
			s:step(input({ brake = true, move = Vector3.xAxis }), ground(), 1 / 60)
		end
		Fixtures.expectNear(s.velocity, Vector3.new(12, 0, 0))
		local still = skater(Vector3.zero)
		still:step(input({ brake = true, move = Vector3.new(0, 0, -0.5) }), ground(), 0.1)
		Fixtures.expectNear(still.velocity, Vector3.new(0, 0, -6)) -- tiptoeSpeed × half the stick
	end)

	it("pumps: more pull downhill, a small push on the flat, nothing uphill", function()
		local downhill = skater(DOWNHILL * 10)
		downhill:step(input({ pump = true }), ground(SLOPE), 0.1)
		expect(downhill.velocity.Magnitude).toBeCloseTo(20.2952, 3) -- 10 + 67.10 × 1.6 × 0.1, then friction and drag
		local flat = skater(Vector3.new(0, 0, -30))
		flat:step(input({ pump = true }), ground(), 0.1)
		Fixtures.expectNear(flat.velocity, Vector3.new(0, 0, -30.3384)) -- + pumpFlatAccel 8
		local uphill = skater(DOWNHILL * -30)
		uphill:step(input({ pump = true }), ground(SLOPE), 0.1)
		Fixtures.expectNear(uphill.velocity, -DOWNHILL * 22.8430) -- no push: 30 − 6.71, then friction and drag
	end)

	it("adds the draft's pull along the way it travels", function()
		local s = skater(Vector3.new(0, 0, -30))
		s:step(input({ draftAccel = 10 }), ground(), 0.1)
		Fixtures.expectNear(s.velocity, Vector3.new(0, 0, -29.788)) -- 31, then friction, drag and coastDecel
	end)
end)

describe("SkateMath off the ground and on walls", function()
	it("holds the root at hoverHeight above the ground", function()
		local high = skater(Vector3.zero)
		high:step(input(), ground(FLAT, 3), 0.1)
		Fixtures.expectNear(high.velocity, Vector3.new(0, -7.5, 0)) -- (2.5 − 3) × hoverSpring 15
		local low = skater(Vector3.zero)
		low:step(input(), ground(FLAT, 2), 0.1)
		Fixtures.expectNear(low.velocity, Vector3.new(0, 7.5, 0))
	end)

	it("leaves the ground when the ray finds nothing, and falls", function()
		local s = skater(Vector3.new(0, 0, -30))
		s:step(input(), ground(FLAT, 0, false), 0.1)
		expect(s.mode).toBe("Airborne")
		Fixtures.expectNear(s.velocity, Vector3.new(0, -19.5808, -29.94))
	end)

	-- Roller Champions' dive gained speed in the air, 69 to 139 km/h (#214): the bleed past softCap is the ground's.
	it("keeps speed past softCap in the air, losing only air drag", function()
		local s = skater(Vector3.new(0, 0, -110))
		s.mode = "Airborne"
		s:step(input(), ground(FLAT, 0, false), 0.1)
		Fixtures.expectNear(s.velocity, Vector3.new(0, -19.5808, -109.78)) -- (0, −19.62, −110) × (1 − 0.02 × 0.1)
	end)

	-- One ceiling for everything (#214): skating, the whip, dives and drops.
	it("never passes hardCap in the air, attached or released", function()
		local over = movement.hardCap + 50
		local falling = skater(Vector3.new(0, 0, -over))
		falling.mode = "Airborne"
		falling:step(input(), ground(FLAT, 0, false), 0.1)
		expect(falling.velocity.Magnitude).toBeCloseTo(movement.hardCap, 3)
		local attached = skater(Vector3.zero)
		attached:follow(Vector3.zero, Vector3.zero, Vector3.new(0, 0, -over), -Vector3.zAxis)
		expect(attached.velocity.Magnitude).toBeCloseTo(movement.hardCap, 3)
		local released = skater(Vector3.new(0, 0, -over))
		released:release(-Vector3.zAxis)
		expect(released.velocity.Magnitude).toBeCloseTo(movement.hardCap, 3)
	end)

	it("lands only when near the ground and moving toward it", function()
		local falling = skater(Vector3.new(0, -20, -30))
		falling.mode = "Airborne"
		falling:step(input(), ground(FLAT, 2.4), 0.1)
		expect(falling.mode).toBe("Grounded")
		-- The hover's 0.1 × 15 up; 30 − (4 + 7.5 + 0.6) × 0.1 along
		Fixtures.expectNear(falling.velocity, Vector3.new(0, 1.5, -28.79))
		local rising = skater(Vector3.new(0, 20, -30))
		rising.mode = "Airborne"
		rising:step(input(), ground(FLAT, 2.4), 0.1)
		expect(rising.mode).toBe("Airborne")
		Fixtures.expectNear(rising.velocity, Vector3.new(0, 0.3792, -29.94))
	end)

	it("lands without losing its facing, even facing straight into the surface", function()
		-- No speed along the surface, and a facing that points into it: head-on against a wall, and straight down
		-- onto the floor after riding up a wall.
		local cases: { { velocity: Vector3, forward: Vector3, normal: Vector3 } } = {
			{ velocity = Vector3.new(0, 0, 10), forward = Vector3.zAxis, normal = -Vector3.zAxis },
			{ velocity = Vector3.new(0, -10, 0), forward = Vector3.yAxis, normal = Vector3.yAxis },
		}
		for _, case in cases do
			local s = skater(case.velocity)
			s.mode = "Airborne"
			s.forward = case.forward
			s:step(input(), ground(case.normal, 2.4), 0.1)
			expect(s.mode).toBe("Grounded")
			expect(s.forward:Dot(case.normal)).toBeCloseTo(0, 5)
			expect(s.forward.Magnitude).toBeCloseTo(1, 5)
			expect(s.velocity.Magnitude < math.huge).toBe(true) -- a NaN fails this
		end
	end)

	-- The owner (#218): each jump costs 10% of the speed, so jumping is no free way around.
	it("jumps along the surface's normal, off walls too, keeping 90% of its speed along the surface", function()
		local flat = skater(Vector3.new(0, 0, -30))
		flat:step(input({ jump = true }), ground(), 1 / 60)
		expect(flat.mode).toBe("Airborne")
		-- (0, 60, −27), then a 1/60 s step of gravity and drag
		Fixtures.expectNear(flat.velocity, Vector3.new(0, 56.7111, -26.991))
		local wall = skater(Vector3.new(0, 0, -50))
		wall:step(input({ jump = true }), ground(Vector3.xAxis), 1 / 60)
		Fixtures.expectNear(wall.velocity, Vector3.new(59.98, -3.2689, -44.985)) -- (60, 0, −45), then the step
	end)

	-- The owner (#218): one more press in the air, once until landing, is an Air Pose: a small hop of about half a
	-- jump, costing speed like a jump.
	it("strikes an Air Pose with a press in the air: a hop that cancels the fall, once until landing", function()
		local inAir = ground(FLAT, 0, false)
		local falling = skater(Vector3.new(0, -30, -40))
		falling.mode = "Airborne"
		falling:step(input({ jump = true }), inAir, 0.1)
		expect(falling.airPosing).toBe(true)
		expect(falling.airPoseReady).toBe(false)
		-- The fall cancelled: (0, 0 + airPoseImpulse 42, −40 × 0.9), then a 0.1 s step of gravity and drag
		Fixtures.expectNear(falling.velocity, Vector3.new(0, 22.3352, -35.928))
		-- A third press is only the air: gravity and drag.
		falling:step(input({ jump = true }), inAir, 0.1)
		Fixtures.expectNear(falling.velocity, Vector3.new(0, 2.7098, -35.8561))
		-- Landing ends the pose and re-arms it.
		falling.velocity = Vector3.new(0, -10, -30)
		falling:step(input(), ground(FLAT, movement.hoverHeight - 0.1), 0.1)
		expect(falling.mode).toBe("Grounded")
		expect(falling.airPosing).toBe(false)
		expect(falling.airPoseReady).toBe(true)
	end)

	-- Real physics on the glass (#216): no speed is needed to stay on a wall, and gravity pulls along it at
	-- wallGravityScale (the owner: about a third, from a ranked player's ride up the glass).
	it("stays on a wall at any speed, pulled along it by a third of gravity", function()
		local wall = Vector3.xAxis -- vertical, facing +X
		local climbing = skater(Vector3.new(0, 10, 0))
		climbing:step(input(), ground(wall), 0.1)
		expect(climbing.mode).toBe("Grounded")
		-- 10 − 196.2 / 3 × 0.1 = 3.46, then 3.46 − (4 + 7.5 + 0.0692) × 0.1
		Fixtures.expectNear(climbing.velocity, Vector3.new(0, 2.3031, 0))
		local still = skater(Vector3.zero)
		still:step(input(), ground(wall), 0.1)
		expect(still.mode).toBe("Grounded")
		-- It slides back down: 6.54, then 6.54 − (4 + 7.5 + 0.1308) × 0.1
		Fixtures.expectNear(still.velocity, Vector3.new(0, -5.3769, 0))
		-- A 45° bank is steeper than wallAngle, so a wall too: 65.4 × sin 45° × 0.1 = 4.6245, then friction, drag and
		-- coastDecel
		local bank = skater(Vector3.zero)
		bank:step(input(), ground(Vector3.new(0, math.cos(math.rad(45)), -math.sin(math.rad(45)))), 0.1)
		expect(bank.velocity.Magnitude).toBeCloseTo(3.4652, 3)
	end)

	-- The owner (#239): on a wall the skates only roll. The stick neither strides nor steers hard and the brake does
	-- nothing, so climbing costs speed and a slow rider curves back down (RC's glass rides), never holding a line.
	it("never strides on a wall: holding the stick along it adds no speed", function()
		local s = skater(Vector3.new(0, 0, -20))
		s:step(input({ move = -Vector3.zAxis }), ground(Vector3.xAxis), 0.1)
		-- (0, −6.54, −20) after a third of gravity, |21.0421| − (4 + 0.4208) × 0.1 = 20.6000 along it
		Fixtures.expectNear(s.velocity, Vector3.new(0, -6.4026, -19.5798))
	end)

	it("steers on a wall no faster than wallTurnRate", function()
		local s = skater(Vector3.new(0, 0, -30))
		s:step(input({ move = Vector3.yAxis }), ground(Vector3.xAxis), 0.1)
		-- Turned 1 × 0.1 rad up (the floor's rate at 30 is 3.38), plus (0, −6.54, 0), then friction and drag
		Fixtures.expectNear(s.velocity, Vector3.new(0, -3.4907, -29.3932))
	end)

	it("ignores the brake on a wall: no standing still on it, no tiptoeing up it", function()
		local held = skater(Vector3.zero)
		held:step(input({ brake = true }), ground(Vector3.xAxis), 0.1)
		Fixtures.expectNear(held.velocity, Vector3.new(0, -5.3769, 0)) -- as with nothing pressed
		local tiptoe = skater(Vector3.zero)
		tiptoe:step(input({ brake = true, move = Vector3.yAxis }), ground(Vector3.xAxis), 0.1)
		-- Sliding down, the stick held: 6.54 − (4 + 0.1308) × 0.1
		Fixtures.expectNear(tiptoe.velocity, Vector3.new(0, -6.1269, 0))
	end)

	it("pumps on a wall as on any slope: more pull on the way down", function()
		local s = skater(Vector3.new(0, -10, 0))
		s:step(input({ pump = true }), ground(Vector3.xAxis), 0.1)
		-- 10 + 65.4 × 1.6 × 0.1 = 20.464, then 20.464 − (4 + 0.4093) × 0.1
		Fixtures.expectNear(s.velocity, Vector3.new(0, -20.0231, 0))
	end)

	it("steers a little in the air", function()
		local s = skater(Vector3.new(0, 0, -30))
		s.mode = "Airborne"
		s:step(input({ move = Vector3.xAxis }), ground(FLAT, 0, false), 0.1)
		expect(math.atan2(s.velocity.X, -s.velocity.Z)).toBeCloseTo(0.1, 4) -- airTurnRate × 0.1
		Fixtures.expectNear(s.velocity, Vector3.new(2.989, -19.5808, -29.7904))
	end)

	it("turns upright in the air at airUprightRate", function()
		local s = skater(Vector3.new(0, 0, -30))
		s.mode = "Airborne"
		s.up = Vector3.xAxis
		s:step(input(), ground(FLAT, 0, false), 0.1)
		expect(math.deg(math.acos(s.up:Dot(Vector3.yAxis)))).toBeCloseTo(55.6225, 3) -- 90° − 6 × 0.1 rad
	end)

	it("stops dead for a freeze and starts again from rest, its Air Pose over and ready again", function()
		local s = skater(Vector3.new(0, 0, -60))
		s.mode = "Airborne"
		s.airPosing = true
		s.airPoseReady = false
		s:stop()
		expect(s.mode).toBe("Grounded")
		expect(s.airPosing).toBe(false)
		expect(s.airPoseReady).toBe(true)
		Fixtures.expectNear(s.velocity, Vector3.zero)
		s:step(input({ move = -Vector3.zAxis }), ground(), 0.1)
		Fixtures.expectNear(s.velocity, Vector3.new(0, 0, -2.594))
	end)
end)

describe("SkateMath pushes and knockdowns", function()
	it("pushes the skater and caps the result at hardCap", function()
		local s = skater(Vector3.new(0, 0, -100))
		s:push(Vector3.new(0, 0, -60), false)
		Fixtures.expectNear(s.velocity, Vector3.new(0, 0, -movement.hardCap))
		expect(s.mode).toBe("Grounded")
	end)

	it("launches with a push that leaves the ground", function()
		local s = skater(Vector3.zero)
		s:push(Vector3.new(0, 110, 0), true)
		expect(s.mode).toBe("Airborne")
		expect(s.velocity.Y).toBeCloseTo(110, 4)
	end)

	it("slides a knocked-down skater, slowing by knockdownDecel and ignoring the stick, pump and jump", function()
		local s = skater(Vector3.new(0, 0, -80))
		s:step(input({ move = Vector3.xAxis, pump = true, jump = true, knockedDown = true }), ground(), 0.5)
		expect(s.mode).toBe("Grounded")
		Fixtures.expectNear(s.forward, -Vector3.zAxis)
		-- 80 − (4 + 0.02 × 80) × 0.5 − 75 × 0.5
		expect(s.velocity.Magnitude).toBeCloseTo(39.7, 2)

		-- Nor does a knocked-down skater steer in the air.
		local flying = skater(Vector3.new(0, 0, -30))
		flying.mode = "Airborne"
		flying:step(input({ move = Vector3.xAxis, knockedDown = true }), ground(FLAT, 0, false), 0.1)
		expect(flying.velocity.X).toBeCloseTo(0, 6)
	end)

	-- The owner (#242): RC's dive glides ~0.3 s at ~70 km/h before the belly slide (Video 6).
	it("glides a diver on the ground, slowed by friction and drag only, ignoring the stick, pump and jump", function()
		local s = skater(Vector3.new(0, 0, -60))
		s:step(input({ move = Vector3.xAxis, pump = true, jump = true, diving = true }), ground(), 0.5)
		expect(s.mode).toBe("Grounded")
		Fixtures.expectNear(s.forward, -Vector3.zAxis)
		-- 60 − (4 + 0.02 × 60) × 0.5: no coastDecel, no knockdownDecel.
		expect(s.velocity.Magnitude).toBeCloseTo(57.4, 2)
	end)

	-- A knockdown locks everything (SkateInput), a dive included.
	it("slides a knocked-down diver as any knocked-down skater", function()
		local s = skater(Vector3.new(0, 0, -80))
		s:step(input({ knockedDown = true, diving = true }), ground(), 0.5)
		-- 80 − (4 + 0.02 × 80) × 0.5 − 75 × 0.5
		expect(s.velocity.Magnitude).toBeCloseTo(39.7, 2)
	end)

	-- The owner (#245, Q13): the Air Pose lasts while the jump key is held.
	it("holds the Air Pose while the jump key is held and ends it when let go, until landing", function()
		local inAir = ground(FLAT, 0, false)
		local s = skater(Vector3.new(0, 10, -40))
		s.mode = "Airborne"
		s:step(input({ jump = true, jumpHeld = true }), inAir, 1 / 60)
		expect(s.airPosing).toBe(true)
		s:step(input({ jumpHeld = true }), inAir, 1 / 60)
		expect(s.airPosing).toBe(true)
		s:step(input(), inAir, 1 / 60)
		expect(s.airPosing).toBe(false)
		-- Holding the key again strikes nothing more until landing.
		s:step(input({ jumpHeld = true }), inAir, 1 / 60)
		expect(s.airPosing).toBe(false)
		expect(s.airPoseReady).toBe(false)
	end)

	-- A dive or a knockdown locks the jump key too (#245): the pose ends, so the touchdown is a dive's, or none.
	it("ends the Air Pose of a skater who dives or is knocked down in the air, the key still held", function()
		local cases: { { [string]: any } } = {
			{ diving = true, jumpHeld = true },
			{ knockedDown = true, jumpHeld = true },
		}
		for _, overrides in cases do
			local s = skater(Vector3.new(0, 10, -40))
			s.mode = "Airborne"
			s.airPosing = true
			s.airPoseReady = false
			s:step(input(overrides), ground(FLAT, 0, false), 1 / 60)
			expect(s.airPosing).toBe(false)
		end
	end)

	-- The owner (#245, Q14): a posed fall gains forward speed down the dive's fall line (RC: ~85 km/h per s).
	it("flies a posed skater down the fall line once falling, as a diver; rising, as anyone", function()
		local inAir = ground(FLAT, 0, false)
		local function flying(velocity: Vector3, posing: boolean): SkateMath.Skater
			local s = skater(velocity)
			s.mode = "Airborne"
			s.airPosing = posing
			s.airPoseReady = not posing
			return s
		end
		local posed, diver = flying(Vector3.new(0, -1, -40), true), flying(Vector3.new(0, -1, -40), false)
		for _ = 1, 30 do
			posed:step(input({ jumpHeld = true }), inAir, 1 / 60)
			diver:step(input({ diving = true }), inAir, 1 / 60)
		end
		Fixtures.expectNear(posed.velocity, diver.velocity)
		expect(posed:shownSpeed()).toBeGreaterThan(40)
		-- Still rising after the hop: gravity straight down, as for anyone in the air.
		local rising, plain = flying(Vector3.new(0, 20, -40), true), flying(Vector3.new(0, 20, -40), false)
		rising:step(input({ jumpHeld = true }), inAir, 1 / 60)
		plain:step(input(), inAir, 1 / 60)
		Fixtures.expectNear(rising.velocity, plain.velocity)
	end)

	-- The owner (#245, Q19): RC's belly touchdowns from the air kept 59-73% of the speed (133 -> 84, 139 -> 101,
	-- 104 -> 70, 97 -> 57 km/h; Videos 5-7).
	it("keeps bellyLandingKeep of the speed through a belly touchdown from the air, and says so", function()
		local keep = movement.bellyLandingKeep
		local touchdown = ground(FLAT, movement.hoverHeight - 0.1)
		local function landed(posing: boolean, overrides: { [string]: any }): SkateMath.Skater
			local s = skater(Vector3.new(0, -10, -60))
			s.mode = "Airborne"
			s.airPosing = posing
			s.airPoseReady = not posing
			s:step(input(overrides), touchdown, 1 / 60)
			return s
		end
		local function slowed(speed: number, extra: number): number
			return speed - (movement.rollingFriction + extra + movement.airDrag * speed) / 60
		end
		-- Held into the ground: 60 x 0.65 = 39 along the floor, then a step of friction, drag and coasting.
		local posed = landed(true, { jumpHeld = true })
		expect(posed.mode).toBe("Grounded")
		expect(posed.landedPosed).toBe(true)
		expect(posed:shownSpeed()).toBeCloseTo(slowed(60 * keep, movement.coastDecel), 3)
		-- A diver too, gliding on.
		local diver = landed(false, { diving = true })
		expect(diver.landedPosed).toBe(false)
		expect(diver:shownSpeed()).toBeCloseTo(slowed(60 * keep, 0), 3)
		-- Let go before the touchdown, or never posing: nothing lost.
		local released = landed(true, {})
		expect(released.landedPosed).toBe(false)
		expect(released:shownSpeed()).toBeCloseTo(slowed(60, movement.coastDecel), 3)
		-- The landing step only, and a step attached behind a teammate is none.
		posed:step(input({ jumpHeld = true }), touchdown, 1 / 60)
		expect(posed.landedPosed).toBe(false)
		local attached = landed(true, { jumpHeld = true })
		attached:follow(Vector3.zero, Vector3.zero, Vector3.zero, -Vector3.zAxis)
		expect(attached.landedPosed).toBe(false)
	end)

	it("stops a knocked-down skater at zero, never backwards", function()
		local s = skater(Vector3.new(0, 0, -10))
		s:step(input({ knockedDown = true }), ground(), 1)
		Fixtures.expectNear(s.velocity, Vector3.zero)
	end)

	it("loses only its velocity into a surface that blocks it, and says whether that changed it", function()
		local wall = Vector3.new(-1, 0, 0)
		local s = skater(Vector3.new(120, -30, 5))
		expect(s:block(wall)).toBe(true)
		Fixtures.expectNear(s.velocity, Vector3.new(0, -30, 5))
		-- Along the wall, or away from it, there is nothing to lose.
		expect(s:block(wall)).toBe(false)
		s.velocity = Vector3.new(-50, 10, 0)
		expect(s:block(wall)).toBe(false)
		Fixtures.expectNear(s.velocity, Vector3.new(-50, 10, 0))
	end)

	-- Roller Champions' speedometer (#233): a standing jump read 0 (the owner's Video 5) and an Air Pose held the
	-- reading (Video 4: 21 -> 21, 38 -> 38).
	it("shows the speed along the surface on the ground and on walls, and across the ground in the air", function()
		-- On the floor: the 2 studs/s along the normal is the hover's pull, not speed. |(30, 0, -40)| = 50.
		local s = skater(Vector3.new(30, 2, -40))
		expect(s:shownSpeed()).toBeCloseTo(50, 4)
		-- On a wall facing +X, riding up and along it: |(0, 30, -40)| = 50.
		s.up = Vector3.xAxis
		s.velocity = Vector3.new(3, 30, -40)
		expect(s:shownSpeed()).toBeCloseTo(50, 4)
		-- Behind a teammate: on the ground too.
		s.mode = "Attached"
		expect(s:shownSpeed()).toBeCloseTo(50, 4)
		-- A standing jump reads 0, and a fall adds nothing to the speed across the ground.
		s.mode = "Airborne"
		s.velocity = Vector3.new(0, movement.jumpImpulse, 0)
		expect(s:shownSpeed()).toBe(0)
		s.velocity = Vector3.new(30, -80, -40)
		expect(s:shownSpeed()).toBeCloseTo(50, 4)
	end)
end)

-- The lunges (#241), in the speedometer's terms (shownSpeed): Roller Champions' tackle peaked at 65-75 km/h whatever
-- the speed before, and its dive went to ~70 km/h, then sped up diving down (Videos 4-6).
describe("SkateMath lunges", function()
	-- The line a diver facing -Z flies along: fallLineDeg (20°) below the facing.
	local LINE = Vector3.new(0, -math.sin(math.rad(movement.fallLineDeg)), -math.cos(math.rad(movement.fallLineDeg)))

	local function airborne(velocity: Vector3): SkateMath.Skater
		local s = skater(velocity)
		s.mode = "Airborne"
		return s
	end

	it("lunges along the facing, never past the ceiling: a faster skater slows to it", function()
		-- From rest, at cruise (60 + 40 held at 60) and at 108 km/h (90, slowed to 60), all facing -Z.
		Fixtures.expectNear(skater(Vector3.zero):lungeChange(40, 60), Vector3.new(0, 0, -40))
		Fixtures.expectNear(skater(Vector3.new(0, 0, -60)):lungeChange(40, 60), Vector3.zero)
		Fixtures.expectNear(skater(Vector3.new(0, 0, -90)):lungeChange(40, 60), Vector3.new(0, 0, 30))
		-- Moving sideways: (50, 0, -40) is 64.03, held at 60: (46.852, 0, -37.482).
		Fixtures.expectNear(skater(Vector3.new(50, 0, 0)):lungeChange(40, 60), Vector3.new(-3.148, 0, -37.482))
		-- In the air, across the ground only: the rise stays.
		Fixtures.expectNear(airborne(Vector3.new(0, 50, -30)):lungeChange(40, 60), Vector3.new(0, 0, -30))
	end)

	it("slows the shown speed down to a ceiling, and leaves a slower skater and the rise alone", function()
		Fixtures.expectNear(skater(Vector3.new(0, 0, -40)):slowChange(25), Vector3.new(0, 0, 15))
		Fixtures.expectNear(skater(Vector3.new(0, 0, -40)):slowChange(50), Vector3.zero)
		Fixtures.expectNear(airborne(Vector3.new(0, 30, -40)):slowChange(10), Vector3.new(0, 0, 30))
	end)

	it("dives along the facing on the ground, at the dive's speed or a faster skater's own", function()
		Fixtures.expectNear(skater(Vector3.new(0, 0, -30)):diveChange(60), Vector3.new(0, 0, -30))
		Fixtures.expectNear(skater(Vector3.new(0, 0, -90)):diveChange(60), Vector3.zero)
	end)

	it("dives down the fall line in the air, at the dive's speed or the shown speed if faster", function()
		-- From 10 across: 60 along the line, (0, -20.521, -56.382).
		local slow = airborne(Vector3.new(0, 0, -10))
		slow:push(slow:diveChange(60), false)
		Fixtures.expectNear(slow.velocity, LINE * 60)
		-- Falling at 30 with 80 across: 80 along it, (0, -27.362, -75.175).
		local fast = airborne(Vector3.new(0, -30, -80))
		fast:push(fast:diveChange(60), false)
		Fixtures.expectNear(fast.velocity, LINE * 80)
	end)

	it("speeds a diver down the fall line by gravity's pull along it, never past hardCap", function()
		local function dived(speed: number, seconds: number): SkateMath.Skater
			local s = airborne(LINE * speed)
			for _ = 1, math.round(seconds * 60) do
				s:step(input({ diving = true }), ground(FLAT, 0, false), 1 / 60)
			end
			return s
		end
		-- 196.2 × sin 20° = 67.1 along the line, less air drag, each 1/60 s: 60 -> 92.782 in 0.5 s, still on the line
		-- (63 studs/s² across the ground: RC's readout climbed ~75 km/h per s).
		local s = dived(60, 0.5)
		Fixtures.expectNear(s.velocity, LINE * 92.782)
		Fixtures.expectNear(s.forward, -Vector3.zAxis)
		Fixtures.expectNear(dived(115, 0.5).velocity, LINE * movement.hardCap)
		-- Rising straight up a wall as they leave it: nothing of that goes down the line, so they start from rest on
		-- it (one step's pull, 67.1 / 60 = 1.118, less drag).
		local rising = airborne(Vector3.new(0, 60, 0))
		rising:step(input({ diving = true }), ground(FLAT, 0, false), 1 / 60)
		Fixtures.expectNear(rising.velocity, LINE * 1.118)
		-- Not diving: gravity straight down, as ever.
		local falling = airborne(Vector3.new(0, 0, -60))
		falling:step(input({ knockedDown = true }), ground(FLAT, 0, false), 0.1)
		Fixtures.expectNear(falling.velocity * Vector3.new(1, 0, 1), Vector3.new(0, 0, -59.88))
		expect(falling.velocity.Y).toBeCloseTo(-19.62 * (1 - 0.02 * 0.1), 3)
	end)
end)

-- The owner (#246): RC's skater rode back down a bank still facing up it, then turned round over ~0.3 s, never in a
-- snap (Video 7, 16.9-17.9 s).
describe("SkateMath facing", function()
	-- The most one step of 1/60 s turns the facing: a half-turn in turnRoundSeconds, π / 0.3 / 60 = 0.1745 rad.
	local STEP_TURN = math.pi / movement.turnRoundSeconds / 60
	local UPHILL = -DOWNHILL

	-- Rolling back down the slope at `speed`, still facing up it, as after a climb.
	local function rollingBack(speed: number): SkateMath.Skater
		local s = skater(DOWNHILL * speed)
		s.forward = UPHILL
		return s
	end

	it("turns its facing toward the way it moves, a half-turn in turnRoundSeconds, never at once", function()
		-- Rolling along +Z while facing -Z, nothing pressed.
		local s = skater(Vector3.new(0, 0, 30))
		s:step(input(), ground(), 1 / 60)
		expect(Vectors.angleBetween(s.forward, -Vector3.zAxis)).toBeCloseTo(STEP_TURN, 4)
		expect(s.forward.Y).toBeCloseTo(0, 6)
		for _ = 1, math.ceil(movement.turnRoundSeconds * 60) do
			s:step(input(), ground(), 1 / 60)
		end
		Fixtures.expectNear(s.forward, Vector3.zAxis)
		-- In the air too.
		local flying = skater(Vector3.new(30, 0, 0))
		flying.mode = "Airborne"
		flying:step(input(), ground(FLAT, 0, false), 1 / 60)
		expect(Vectors.angleBetween(flying.forward, -Vector3.zAxis)).toBeCloseTo(STEP_TURN, 4)
		-- Off the top of a wall ridden straight up, the facing (up) lies on no level plane: nothing to turn from.
		local offTheTop = skater(Vector3.new(0, 5, 30))
		offTheTop.mode = "Airborne"
		offTheTop.forward = Vector3.yAxis
		offTheTop:step(input(), ground(FLAT, 0, false), 1 / 60)
		Fixtures.expectNear(offTheTop.forward, Vector3.zAxis)
		-- Steering at speed turns the way it moves slower than that (3.38 rad/s at 30), and the facing keeps up.
		local steering = skater(Vector3.new(0, 0, -30))
		for _ = 1, 10 do
			steering:step(input({ move = Vector3.xAxis }), ground(), 1 / 60)
		end
		Fixtures.expectNear(steering.forward, steering.velocity.Unit)
	end)

	it("rides backwards down a slope while the stick holds the way it rolls, and on across the flat below", function()
		local s = rollingBack(10)
		for _ = 1, 30 do
			s:step(input({ move = DOWNHILL }), ground(SLOPE), 1 / 60)
		end
		-- Still facing up the slope, its back leading, speeding up downhill as anyone would.
		Fixtures.expectNear(s.forward, UPHILL)
		expect(s.velocity:Dot(DOWNHILL)).toBeGreaterThan(10)
		-- Onto the flat at the foot, the stick still held the way it rolls: still backwards.
		for _ = 1, 10 do
			s:step(input({ move = -Vector3.zAxis }), ground(), 1 / 60)
		end
		Fixtures.expectNear(s.forward, Vector3.zAxis)
	end)

	it("turns round from riding backwards once the stick lets go or steers elsewhere, never at once", function()
		-- Let go; steering sideways; and S with A, 45° off the way back, outside backwardsConeDeg (30).
		local moves: { Vector3 } = { Vector3.zero, Vector3.xAxis, (DOWNHILL + Vector3.xAxis).Unit }
		for _, move in moves do
			local s = rollingBack(10)
			s:step(input({ move = DOWNHILL }), ground(SLOPE), 1 / 60)
			Fixtures.expectNear(s.forward, UPHILL)
			s:step(input({ move = move }), ground(SLOPE), 1 / 60)
			expect(Vectors.angleBetween(s.forward, UPHILL)).toBeCloseTo(STEP_TURN, 4)
			for _ = 1, math.ceil(movement.turnRoundSeconds * 60) do
				s:step(input({ move = move }), ground(SLOPE), 1 / 60)
			end
			expect(s.forward:Dot(s.velocity.Unit)).toBeCloseTo(1, 4)
		end
	end)

	-- The owner (#246, Q23): from a stop, S turns the skater round smoothly; riding backwards needs being carried back.
	it(
		"turns round, never riding backwards, pushing off from a stop, after a freeze or an attach, and in the air",
		function()
			-- Pushed off against the facing: how far the facing turned in one step.
			local function pushedOff(s: SkateMath.Skater): number
				local before = Vectors.alongSurface(s.forward, FLAT).Unit
				s:step(input({ move = -before }), ground(), 1 / 60)
				return Vectors.angleBetween(s.forward, before)
			end
			expect(pushedOff(skater(Vector3.zero))).toBeCloseTo(STEP_TURN, 4)
			-- A freeze or an attach ends riding backwards.
			local frozen = rollingBack(10)
			frozen:step(input({ move = DOWNHILL }), ground(SLOPE), 1 / 60)
			frozen:stop()
			expect(pushedOff(frozen)).toBeCloseTo(STEP_TURN, 4)
			local attached = rollingBack(10)
			attached:step(input({ move = DOWNHILL }), ground(SLOPE), 1 / 60)
			attached:follow(Vector3.zero, Vector3.zero, Vector3.zero, attached.forward)
			expect(pushedOff(attached)).toBeCloseTo(STEP_TURN, 4)
			-- Nothing carries a skater back in the air: flying against the facing, the stick along the way, they turn
			-- round.
			local flying = skater(Vector3.new(0, 0, 30))
			flying.mode = "Airborne"
			flying:step(input({ move = Vector3.zAxis }), ground(FLAT, 0, false), 1 / 60)
			expect(Vectors.angleBetween(flying.forward, -Vector3.zAxis)).toBeCloseTo(STEP_TURN, 4)
		end
	)
end)

-- Loop physics (A3). A roof is an arc around the origin with the skater inside the tube, so its normal at angle phi
-- points back at the centre. Past straight up gravity pulls the skater off unless the arc bends hard enough:
-- speed² × curvature must reach gravity's pull into the surface. The curvature is measured over curvatureWindow studs
-- of the skater's path, so a roof of flat strips (the arena's) reads as the arc it approximates.
describe("SkateMath riding the roof by loop physics", function()
	local RADIUS = 22
	local DT = 1 / 60
	-- The arena's roof: 21 flat strips over the half circle.
	local ROOF_STRIPS = 21

	local function normalAt(phi: number): Vector3
		return Vector3.new(-math.cos(phi), -math.sin(phi), 0)
	end

	local function tangentAt(phi: number, speed: number): Vector3
		return Vector3.new(-math.sin(phi), math.cos(phi), 0) * speed
	end

	-- Rides an arc of `radius` at `speed` from angle `from` to `to`, one step per DT, and says whether the skater
	-- stayed on. Each frame moves the full speed × DT, as in a real game. With `strips`, the arc is that many flat
	-- strips over a half circle, so the normal holds still across a strip and turns at its edges. The skater first
	-- rides the flat surface the arc starts from (the wall below a roof, the floor before a quarter-pipe), as in the
	-- arena.
	local function staysOn(speed: number, radius: number, from: number, to: number, strips: number?): boolean
		local s = skater(Vector3.zero)
		for _ = 1, 10 do
			s.velocity = tangentAt(from, speed)
			s:step(input(), ground(normalAt(from)), DT)
		end
		local step = speed * DT / radius
		for frame = 0, math.ceil((to - from) / step) do
			local at = from + frame * step
			local facing = at
			if strips ~= nil then
				local width = math.pi / strips
				facing = (math.floor(at / width) + 0.5) * width
			end
			s.velocity = tangentAt(at, speed)
			s:step(input(), ground(normalAt(facing)), DT)
			if s.mode == "Airborne" then
				return false
			end
		end
		return true
	end

	it("holds the top of a loop, upside down, only above the speed its curve needs", function()
		-- The top needs speed² ≥ gravity × radius: 196.2 × 22, so 65.7 studs/s.
		expect(staysOn(70, RADIUS, 0, math.pi / 2)).toBe(true)
		expect(staysOn(60, RADIUS, 0, math.pi / 2)).toBe(false)
	end)

	it("reads a roof of flat strips as the arc it makes, so the same speeds hold and fall", function()
		expect(staysOn(70, RADIUS, 0, math.pi / 2, ROOF_STRIPS)).toBe(true)
		expect(staysOn(60, RADIUS, 0, math.pi / 2, ROOF_STRIPS)).toBe(false)
		-- Just above the arc's 65.7, the strips hold as the arc does. A plain average of the window's turning dips at
		-- the top and drops a skater here (measured: up to 66.5).
		expect(staysOn(66.5, RADIUS, 0, math.pi / 2)).toBe(true)
		expect(staysOn(66.5, RADIUS, 0, math.pi / 2, ROOF_STRIPS)).toBe(true)
	end)

	it("holds where gravity pulls half as hard as at the top, above the speed its curve needs there", function()
		-- Pull 98.1 needs speed ≥ 46.5 on this arc.
		expect(staysOn(50, RADIUS, 0, math.pi / 6)).toBe(true)
		expect(staysOn(40, RADIUS, 0, math.pi / 6)).toBe(false)
	end)

	it("lets go of a flat ceiling once the corner that led onto it is behind, at any speed", function()
		local s = skater(Vector3.zero)
		local wall, ceiling = Vector3.new(-1, 0, 0), Vector3.new(0, -1, 0)
		local speed = movement.hardCap
		for _ = 1, 10 do
			s.velocity = Vector3.new(0, speed, 0)
			s:step(input(), ground(wall), DT)
		end
		s.velocity = Vector3.new(-speed, 0, 0)
		s:step(input(), ground(ceiling), DT)
		-- The corner's turn is still within the window: the skater holds for now.
		expect(s.mode).toBe("Grounded")
		local frames = 0
		while s.mode == "Grounded" and frames < 60 do
			s.velocity = Vector3.new(-speed, 0, 0)
			s:step(input(), ground(ceiling), DT)
			frames += 1
		end
		expect(s.mode).toBe("Airborne")
		-- Within the window plus a frame's travel (hardCap × DT, about 2 studs).
		expect(frames * speed * DT).toBeLessThan(movement.curvatureWindow + speed * DT + 1e-6)
	end)

	it("holds a slow skater on a tight overhang while its curve does, with no wall speed needed (#216)", function()
		-- A quarter-pipe of radius 2 from the floor to 5° past straight up: speed² / 2 must reach 196.2 × sin 5°,
		-- 17.1, so it holds anyone above 5.85 studs/s.
		local floor, overhang = -math.pi / 2, math.rad(5)
		expect(staysOn(30, 2, floor, overhang)).toBe(true)
		expect(staysOn(7, 2, floor, overhang)).toBe(true)
		expect(staysOn(5, 2, floor, overhang)).toBe(false)
	end)

	it("keeps a skater riding a vertical wall at 40 studs/s, where gravity does not pull off", function()
		local s = skater(Vector3.new(0, 40, 0))
		s:step(input(), ground(Vector3.new(0, 0, 1)), DT)
		expect(s.mode).toBe("Grounded")
	end)

	-- Built faces lean a hair: rays at the arena's glass read normals up to 6.5e-5 past straight up (measured, #234).
	-- That is float noise, not an overhang: a flat face has no curve, so the loop rule would drop every skater on it.
	it("keeps a skater riding up a wall that leans past vertical only by float noise", function()
		local s = skater(Vector3.new(0, 40, 0))
		s:step(input(), ground(Vector3.new(0, -6.5e-5, 1).Unit), DT)
		expect(s.mode).toBe("Grounded")
	end)
end)
