--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Attributes = require(ReplicatedStorage.Shared.Net.Attributes)
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
		knockdown = nil,
		diving = false,
	}
	local fields: any = record
	local changes: { [string]: any } = overrides or {}
	for key, value in changes do
		-- A retired or misspelt field would be ignored silently: only SkateInput's own (knockdown is the optional one).
		assert(key == "knockdown" or fields[key] ~= nil, `SkateInput has no field {key}`)
		fields[key] = value
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

	it("coasts without input, slowed by rolling friction and air drag only", function()
		local s = skater(Vector3.new(0, 0, -60))
		s:step(input(), ground(), 0.1)
		Fixtures.expectNear(s.velocity, Vector3.new(0, 0, -59.48)) -- 60 − (4 + 1.2) × 0.1
	end)

	-- The owner (#288, Q67-Q70): friction acts the same whether keys are pressed or not, so a skater let go at the
	-- stride's top speed rolls on (RC's Video 27: ~11 s to a stop after ~2 s of W).
	it("rolls from cruiseSpeed to a stop in about 10.4 s on flat ground with nothing pressed", function()
		local s = skater(Vector3.new(0, 0, -movement.cruiseSpeed))
		local steps = 0
		while s.velocity.Magnitude > 0 and steps < 1200 do
			s:step(input(), ground(), 1 / 60)
			steps += 1
		end
		-- dv/dt = −(4 + 0.02 v): 50 × ln((4 + 0.92) / 4) = 10.35 s
		expect(steps / 60).toBeCloseTo(10.35, 1)
	end)

	it("strides only up to cruiseSpeed and settles there", function()
		local forward = input({ move = -Vector3.zAxis })
		local atCruise = skater(Vector3.new(0, 0, -46))
		atCruise:step(forward, ground(), 0.1)
		-- No push at cruiseSpeed (55 km/h, #265): it coasts, 46 − (4 + 0.02 × 46) × 0.1.
		Fixtures.expectNear(atCruise.velocity, Vector3.new(0, 0, -45.508))
		local s = skater(Vector3.zero)
		for _ = 1, 600 do
			s:step(forward, ground(), 1 / 60)
		end
		for _ = 1, 120 do
			s:step(forward, ground(), 1 / 60)
			-- The reference model stays between 45.92 and 46.42: 46 − (4 + 0.92) / 60 and 46 + (30 − 4.93) / 60.
			expect(s.velocity.Magnitude > 45.5 and s.velocity.Magnitude < 46.5).toBe(true)
		end
	end)

	it("speeds up downhill by gravity's pull along the surface", function()
		local s = skater(DOWNHILL * 10)
		s:step(input(), ground(SLOPE), 0.1)
		-- + 196.2 × sin 20° × 0.1, then friction and drag
		Fixtures.expectNear(s.velocity, DOWNHILL * 16.2770)
	end)

	it("scales speeding up down between softCap and hardCap", function()
		local s = skater(DOWNHILL * 115)
		s:step(input(), ground(SLOPE), 0.01)
		-- 67.10 × (121 − 115)/(121 − 90) = 12.99 studs/s², then friction and drag, then the bleed:
		-- 90 + 25.067 × e^−0.05
		expect(s.velocity.Magnitude).toBeCloseTo(113.8443, 3)
	end)

	-- Roller Champions (#214): a skater whipped to 144 km/h was back near 110 within about a second.
	it("bleeds speed past softCap off, the further over the faster, and never exceeds hardCap", function()
		local function after(speed: number): number
			local s = skater(Vector3.new(0, 0, -speed))
			s:step(input(), ground(), 0.1)
			return s.velocity.Magnitude
		end
		-- 120 − (4 + 2.4) × 0.1 = 119.36, then 90 + 29.36 × e^−0.5
		expect(after(120)).toBeCloseTo(107.8077, 3)
		expect(after(100)).toBeCloseTo(95.7014, 3) -- 99.4, then 90 + 9.4 × e^−0.5
		expect(after(80)).toBeCloseTo(79.44, 3) -- under softCap: friction and drag only
		expect(after(150)).toBeCloseTo(121, 3) -- 125.97 after the bleed, then hardCap
	end)

	-- The owner (#298, Q85): turns a quarter quicker than #272's, a cruise loop 4.1 body lengths across in 1.63 s.
	it("turns toward the stick at a rate that shrinks with speed", function()
		local function turned(speed: number): number
			local s = skater(Vector3.new(0, 0, -speed))
			s:step(input({ move = Vector3.xAxis }), ground(), 0.1)
			return math.atan2(s.velocity.X, -s.velocity.Z)
		end
		expect(turned(70)).toBeCloseTo(0.32645, 4) -- lerp(5.0, 2.0, 70/121) × 0.1
		expect(turned(121)).toBeCloseTo(0.2, 4)
		local still = skater(Vector3.zero)
		still:step(input({ move = Vector3.xAxis }), ground(), 0.1)
		Fixtures.expectNear(still.velocity, Vector3.new(2.594, 0, 0)) -- from rest it faces the stick at once
	end)

	-- Roller Champions (#266, Videos 14-15): a stick held against the motion brakes the skater to a stop before
	-- they go its way, never carving a U-turn at speed. The owner (#298, Q85): its part back brakes like the Brake
	-- key, from cruise stopped in 0.37 s over 1.5 body lengths (a stride's push took 1.33 s over 5.2).
	it("brakes against a stick held straight back, then skates its way, never carving round", function()
		local back = input({ move = Vector3.zAxis })
		local s = skater(Vector3.new(0, 0, -46))
		s:step(back, ground(), 0.1)
		-- 46 − 120 × 0.1 = 34, then 34 − (4 + 0.02 × 34) × 0.1
		Fixtures.expectNear(s.velocity, Vector3.new(0, 0, -33.532))
		local held = skater(Vector3.new(0, 0, -46))
		local steps = 0
		while held.velocity.Z < 0 and steps < 600 do
			held:step(back, ground(), 1 / 60)
			expect(math.abs(held.velocity.X) < 1e-6).toBe(true)
			steps += 1
		end
		-- dv/dt = −(120 + 4 + 0.02 v) from 46: 50 × ln(124.92 / 124) = 0.370 s, the 23rd step at 60 a second
		expect(steps / 60).toBeCloseTo(0.38, 1)
		for _ = 1, 30 do
			held:step(back, ground(), 1 / 60)
		end
		-- Then it strides the stick's way, 14.48 studs/s half a second later (s48 worked298.py).
		expect(held.velocity.Z).toBeCloseTo(14.48, 1)
	end)

	it("brakes with the part of the stick against the motion and turns only with the part across", function()
		local s = skater(Vector3.new(0, 0, -46))
		s:step(input({ move = Vector3.new(-1, 0, 1).Unit }), ground(), 0.1)
		-- 135° off: back 0.7071 brakes 120 × 0.7071; across 0.7071 turns 0.7071 × lerp(5.0, 2.0, 46/121) × 0.1 =
		-- 0.27291 rad toward −X; 46 − 8.4853 = 37.5147, then 37.5147 − (4 + 0.7503) × 0.1 = 37.0397 along it.
		Fixtures.expectNear(s.velocity, Vector3.new(-9.9834, 0, -35.6689))
	end)

	-- A gamepad's or the touch stick's part-way push (#298 found it untested).
	it("strides and brakes as hard as the stick is pushed", function()
		local half = skater(Vector3.zero)
		half:step(input({ move = Vector3.new(0, 0, -0.5) }), ground(), 0.1)
		Fixtures.expectNear(half.velocity, Vector3.new(0, 0, -1.097)) -- 30 × 0.5 × 0.1 = 1.5, then friction and drag
		local back = skater(Vector3.new(0, 0, -46))
		back:step(input({ move = Vector3.new(0, 0, 0.5) }), ground(), 0.1)
		-- 46 − 120 × 0.5 × 0.1 = 40, then friction and drag
		Fixtures.expectNear(back.velocity, Vector3.new(0, 0, -39.52))
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
		Fixtures.expectNear(s.velocity, Vector3.new(0, 0, -30.538)) -- 31, then friction and drag
	end)
end)

-- The owner (#273, Q38): Roller Champions' skater crept up a bank at 1-5 km/h with W held (Video 20), where ours
-- stopped short of the outer wall's foot. Holding the stick up a slope gentler than crawlLimitDeg, the speed up it
-- never falls below crawlSpeed (3.33 studs/s, 4 km/h).
describe("SkateMath crawling up slopes", function()
	-- A surface `deg` from flat falling toward -Z, and the way up it (where the stick +Z points).
	local function slope(deg: number): (Vector3, Vector3)
		local tilt = math.rad(deg)
		return Vector3.new(0, math.cos(tilt), -math.sin(tilt)), Vector3.new(0, math.sin(tilt), math.cos(tilt))
	end
	local UP_IT = input({ move = Vector3.zAxis })

	it("crawls up a slope gentler than crawlLimitDeg at crawlSpeed, walls under it included", function()
		for _, deg in { 5, 20, 39, 44 } do
			local normal, uphill = slope(deg)
			local s = skater(Vector3.zero)
			s:step(UP_IT, ground(normal), 0.1)
			Fixtures.expectNear(s.velocity, uphill * 3.33)
		end
		-- And it lasts: a second up 20 deg, where the stride (30) loses to gravity's pull (67.1).
		local normal, uphill = slope(20)
		local s = skater(Vector3.zero)
		for _ = 1, 60 do
			s:step(UP_IT, ground(normal), 1 / 60)
		end
		Fixtures.expectNear(s.velocity, uphill * 3.33)
		-- Already faster than the crawl: the stride and gravity only, 20 + (30 - 67.1) x 0.1, then friction and drag.
		local climbing = skater(uphill * 20)
		climbing:step(UP_IT, ground(normal), 0.1)
		Fixtures.expectNear(climbing.velocity, uphill * 15.857)
	end)

	it("crawls only as hard as the stick points along the heading", function()
		local normal, uphill = slope(39)
		local s = skater(uphill)
		s:step(input({ move = Vector3.new(1, 0, 1).Unit }), ground(normal), 0.1)
		-- The stick 52.15 deg off the way up; on a wall the heading turns 0.1 rad toward it (wallTurnRate), and the
		-- crawl along it is 3.33 x cos 46.42 deg = 2.2957.
		Fixtures.expectNear(s.velocity, Vector3.new(1.41, 1.3629, 1.6831))
	end)

	it("slides back down a slope steeper than crawlLimitDeg", function()
		-- From rest, 0.1 s of gravity's pull down it, then friction and drag; a wall takes no stride.
		for _, case in { { 46, 13.6852 }, { 50, 14.5997 } } do
			local normal, uphill = slope(case[1])
			local s = skater(Vector3.zero)
			s:step(UP_IT, ground(normal), 0.1)
			Fixtures.expectNear(s.velocity, uphill * -case[2])
		end
	end)

	it("never crawls with no stick, with the stick against the motion, or on the flat", function()
		local normal, uphill = slope(20)
		-- Nothing pressed, facing up it: gravity, friction and drag.
		local still = skater(Vector3.zero)
		still.forward = uphill
		still:step(input(), ground(normal), 0.1)
		Fixtures.expectNear(still.velocity, uphill * -6.297)
		-- Sliding down at 20 with the stick up: it brakes like the Brake key (#298), and that is all: 20 + (67.1046
		-- − 120) × 0.1 = 14.7105 down it, then friction and drag.
		local sliding = skater(uphill * -20)
		sliding:step(UP_IT, ground(normal), 0.1)
		Fixtures.expectNear(sliding.velocity, uphill * -14.281)
		-- Creeping up a 39 deg wall at 0.5 with the stick pointing back down: no crawl, they slide back.
		local wallNormal, upWall = slope(39)
		local turning = skater(upWall * 0.5)
		turning:step(input({ move = -Vector3.zAxis }), ground(wallNormal), 0.1)
		Fixtures.expectNear(turning.velocity, upWall * -11.4236)
		-- 2 deg, flatter than pumpFlatSlopeDeg: the stride alone, so float noise on a level floor jump-starts no one.
		local gentle, upGentle = slope(2)
		local starting = skater(Vector3.zero)
		starting:step(UP_IT, ground(gentle), 0.1)
		Fixtures.expectNear(starting.velocity, upGentle * 1.9106)
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
		-- The hover's 0.1 × 15 up; 30 − (4 + 0.6) × 0.1 along
		Fixtures.expectNear(falling.velocity, Vector3.new(0, 1.5, -29.54))
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

	-- The owner (#218): each jump costs 10% of the speed, so jumping is no free way around. On a wall it goes up along
	-- it, never off it (#267, RC Video 14: a jump riding up the glass rose along it).
	it("jumps along a floor's normal and up along a wall, keeping 90% of its speed along the surface", function()
		local flat = skater(Vector3.new(0, 0, -30))
		flat:step(input({ jump = true }), ground(), 1 / 60)
		expect(flat.mode).toBe("Airborne")
		-- (0, jumpImpulse 48.99, −27), then a 1/60 s step of gravity and drag
		Fixtures.expectNear(flat.velocity, Vector3.new(0, 45.7048, -26.991))
		local wall = skater(Vector3.new(0, 0, -50))
		wall:step(input({ jump = true }), ground(Vector3.xAxis), 1 / 60)
		Fixtures.expectNear(wall.velocity, Vector3.new(0, 45.7048, -44.985)) -- (0, 48.99, −45), then the step
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
		-- The fall cancelled: (0, 0 + airPoseImpulse 34.29, −40 × 0.9), then a 0.1 s step of gravity and drag
		Fixtures.expectNear(falling.velocity, Vector3.new(0, 14.6407, -35.928))
		-- A third press is only the air: gravity and drag.
		falling:step(input({ jump = true }), inAir, 0.1)
		Fixtures.expectNear(falling.velocity, Vector3.new(0, -4.9694, -35.8561))
		-- Landing ends the pose and re-arms it.
		falling.velocity = Vector3.new(0, -10, -30)
		falling:step(input(), ground(FLAT, movement.hoverHeight - 0.1), 0.1)
		expect(falling.mode).toBe("Grounded")
		expect(falling.airPosing).toBe(false)
		expect(falling.airPoseReady).toBe(true)
	end)

	-- Real physics on the glass (#216): no speed is needed to stay on a wall. One gravity everywhere (the owner,
	-- #256, Q25): a wall pulls at full strength, like the floor and the air.
	it("stays on a wall at any speed, pulled along it by full gravity", function()
		local wall = Vector3.xAxis -- vertical, facing +X
		local climbing = skater(Vector3.new(0, 30, 0))
		climbing:step(input(), ground(wall), 0.1)
		expect(climbing.mode).toBe("Grounded")
		-- 30 − 196.2 × 0.1 = 10.38, then 10.38 − (4 + 0.2076) × 0.1
		Fixtures.expectNear(climbing.velocity, Vector3.new(0, 9.9592, 0))
		local still = skater(Vector3.zero)
		still:step(input(), ground(wall), 0.1)
		expect(still.mode).toBe("Grounded")
		-- It slides back down: 19.62, then 19.62 − (4 + 0.3924) × 0.1
		Fixtures.expectNear(still.velocity, Vector3.new(0, -19.1808, 0))
		-- A 45° bank is steeper than wallAngle, so a wall too: 196.2 × sin 45° × 0.1 = 13.8734, then friction and drag
		local bank = skater(Vector3.zero)
		bank:step(input(), ground(Vector3.new(0, math.cos(math.rad(45)), -math.sin(math.rad(45)))), 0.1)
		expect(bank.velocity.Magnitude).toBeCloseTo(13.4457, 3)
	end)

	-- The owner (#239): on a wall the skates only roll. The stick neither strides nor steers hard and the brake does
	-- nothing, so climbing costs speed and a slow rider curves back down (RC's glass rides), never holding a line.
	it("never strides on a wall: holding the stick along it adds no speed", function()
		local s = skater(Vector3.new(0, 0, -20))
		s:step(input({ move = -Vector3.zAxis }), ground(Vector3.xAxis), 0.1)
		-- (0, −19.62, −20) after gravity, |28.0169| − (4 + 0.5603) × 0.1 = 27.5608 along it
		Fixtures.expectNear(s.velocity, Vector3.new(0, -19.3006, -19.6745))
	end)

	it("steers on a wall no faster than wallTurnRate", function()
		local s = skater(Vector3.new(0, 0, -30))
		s:step(input({ move = Vector3.yAxis }), ground(Vector3.xAxis), 0.1)
		-- Turned 1 × 0.1 rad up (the floor's rate at 30 is 3.38), plus (0, −19.62, 0), then friction and drag
		Fixtures.expectNear(s.velocity, Vector3.new(0, -16.3971, -29.441))
	end)

	it("neither brakes nor turns on a wall with the stick held back: the skates only roll", function()
		local s = skater(Vector3.new(0, 0, -20))
		s:step(input({ move = Vector3.zAxis }), ground(Vector3.xAxis), 0.1)
		-- As with the stick held along the way: (0, −19.62, −20), then |28.0169| − (4 + 0.5603) × 0.1 along it
		Fixtures.expectNear(s.velocity, Vector3.new(0, -19.3006, -19.6745))
	end)

	it("ignores the brake on a wall: no standing still on it, no tiptoeing up it", function()
		local held = skater(Vector3.zero)
		held:step(input({ brake = true }), ground(Vector3.xAxis), 0.1)
		Fixtures.expectNear(held.velocity, Vector3.new(0, -19.1808, 0)) -- as with nothing pressed
		local tiptoe = skater(Vector3.zero)
		tiptoe:step(input({ brake = true, move = Vector3.yAxis }), ground(Vector3.xAxis), 0.1)
		-- Sliding down, the stick held: 19.62 − (4 + 0.3924) × 0.1
		Fixtures.expectNear(tiptoe.velocity, Vector3.new(0, -19.1808, 0))
	end)

	it("pumps on a wall as on any slope: more pull on the way down", function()
		local s = skater(Vector3.new(0, -10, 0))
		s:step(input({ pump = true }), ground(Vector3.xAxis), 0.1)
		-- 10 + 196.2 × 1.6 × 0.1 = 41.392, then 41.392 − (4 + 0.8278) × 0.1
		Fixtures.expectNear(s.velocity, Vector3.new(0, -40.9092, 0))
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

	it("slides a knocked-down skater, ignoring the stick, pump and jump", function()
		local s = skater(Vector3.new(0, 0, -80))
		s:step(input({ move = Vector3.xAxis, pump = true, jump = true, knockdown = "Hit" }), ground(), 0.5)
		expect(s.mode).toBe("Grounded")
		Fixtures.expectNear(s.forward, -Vector3.zAxis)
		-- A tackle's slide stops in 1.5 s: 80 × (1 − 0.5 / 1.5)
		expect(s.velocity.Magnitude).toBeCloseTo(53.33, 2)

		-- Nor does a knocked-down skater steer in the air.
		local flying = skater(Vector3.new(0, 0, -30))
		flying.mode = "Airborne"
		flying:step(input({ move = Vector3.xAxis, knockdown = "Hit" }), ground(FLAT, 0, false), 0.1)
		expect(flying.velocity.X).toBeCloseTo(0, 6)
	end)

	-- The owner (#242): RC's dive glides ~0.3 s at ~70 km/h before the belly slide (Video 6).
	it("glides a diver on the ground, slowed by friction and drag only, ignoring the stick, pump and jump", function()
		local s = skater(Vector3.new(0, 0, -60))
		s:step(input({ move = Vector3.xAxis, pump = true, jump = true, diving = true }), ground(), 0.5)
		expect(s.mode).toBe("Grounded")
		Fixtures.expectNear(s.forward, -Vector3.zAxis)
		-- 60 − (4 + 0.02 × 60) × 0.5: friction and drag, no slide.
		expect(s.velocity.Magnitude).toBeCloseTo(57.4, 2)
	end)

	-- A knockdown locks everything (SkateInput), a dive included.
	it("slides a knocked-down diver by the knockdown's slide, not the glide", function()
		local s = skater(Vector3.new(0, 0, -80))
		s:step(input({ knockdown = "Dive", diving = true }), ground(), 0.5)
		-- A dive's slide stops in 0.8 s: 80 × (1 − 0.5 / 0.8)
		expect(s.velocity.Magnitude).toBeCloseTo(30, 2)
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
			{ knockdown = "Hit", jumpHeld = true },
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

	-- The owner (#278, Q76): a posed fall is a plain fall, the pose's hop then gravity only, so a moving skater goes on
	-- by their own momentum and gains nothing (RC, Video 7: an Uppercut + Air Pose touched down 1.7-2.0 s after the
	-- Uppercut; ours down #245's fall line took 2.3-2.5 s, as a plain fall 1.6-1.8 s). Only a diver flies the line.
	it("flies a posed skater as anyone in the air, rising or falling, steering included", function()
		local inAir = ground(FLAT, 0, false)
		local function flying(velocity: Vector3, posing: boolean): SkateMath.Skater
			local s = skater(velocity)
			s.mode = "Airborne"
			s.airPosing = posing
			s.airPoseReady = not posing
			return s
		end
		for _, velocity in { Vector3.new(0, 20, -40), Vector3.new(0, -1, -40) } do
			local posed, plain = flying(velocity, true), flying(velocity, false)
			for _ = 1, 30 do
				posed:step(input({ jumpHeld = true, move = Vector3.xAxis }), inAir, 1 / 60)
				plain:step(input({ move = Vector3.xAxis }), inAir, 1 / 60)
			end
			expect(posed.airPosing).toBe(true)
			Fixtures.expectNear(posed.velocity, plain.velocity)
		end
	end)

	-- The owner (#278, Q43): "if he jumps standing still and air pose, he shouldn't go forward". Before, the pose fell
	-- down the fall line below the facing: a standing jump's pose drifted 6.1 body lengths forward (at gravity 130.8).
	it("lands a standing jump with an Air Pose at its top where it took off, as a plain fall", function()
		local s = skater(Vector3.zero)
		s:step(input({ jump = true }), ground(), 1 / 60)
		local position, steps, posed = s.velocity / 60, 1, false
		while position.Y > 0 and steps < 600 do
			local press = not posed and s.velocity.Y <= 0
			posed = posed or press
			s:step(input({ jump = press, jumpHeld = posed }), ground(FLAT, 0, false), 1 / 60)
			position += s.velocity / 60
			steps += 1
		end
		expect(s.airPosing).toBe(true)
		expect(position.X).toBeCloseTo(0, 6)
		expect(position.Z).toBeCloseTo(0, 6)
		-- Worked (s48 worked278.py, gravity and linear drag in closed form): up 0.2491 s to 6.096, the hop 0.1745 s
		-- to 2.9895 more, down 0.3046 s: 0.7282 s, 43.69 steps; a step's press and landing each round up by one.
		expect(math.abs(steps / 60 - 0.7282) <= 2 / 60).toBe(true)
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
		local function slowed(speed: number): number
			return speed - (movement.rollingFriction + movement.airDrag * speed) / 60
		end
		-- Held into the ground: 60 x 0.65 = 39 along the floor, then a step of friction and drag.
		local posed = landed(true, { jumpHeld = true })
		expect(posed.mode).toBe("Grounded")
		expect(posed.landedPosed).toBe(true)
		expect(posed:shownSpeed()).toBeCloseTo(slowed(60 * keep), 3)
		-- A diver too, gliding on.
		local diver = landed(false, { diving = true })
		expect(diver.landedPosed).toBe(false)
		expect(diver:shownSpeed()).toBeCloseTo(slowed(60 * keep), 3)
		-- Let go before the touchdown, or never posing: nothing lost.
		local released = landed(true, {})
		expect(released.landedPosed).toBe(false)
		expect(released:shownSpeed()).toBeCloseTo(slowed(60), 3)
		-- The landing step only, and a step attached behind a teammate is none.
		posed:step(input({ jumpHeld = true }), touchdown, 1 / 60)
		expect(posed.landedPosed).toBe(false)
		local attached = landed(true, { jumpHeld = true })
		attached:follow(Vector3.zero, Vector3.zero, Vector3.zero, -Vector3.zAxis)
		expect(attached.landedPosed).toBe(false)
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
		-- From rest, at 72 km/h (60 + 40 held at 60) and at 108 km/h (90, slowed to 60), all facing -Z.
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

	it("turns the facing toward a strike's target across the surface, at most by the given angle", function()
		local s = skater(Vector3.zero)
		s:faceToward(Vector3.new(10, 5, 0), math.huge)
		Fixtures.expectNear(s.forward, Vector3.xAxis)
		-- 30° of the 90° toward +X.
		local partway = skater(Vector3.zero)
		partway:faceToward(Vector3.new(10, 0, 0), math.rad(30))
		Fixtures.expectNear(partway.forward, Vector3.new(0.5, 0, -0.866))
		-- Straight above lies nowhere across the ground: the facing stays.
		local above = skater(Vector3.zero)
		above:faceToward(Vector3.new(0, 10, 0), math.huge)
		Fixtures.expectNear(above.forward, -Vector3.zAxis)
		-- In the air across the ground below.
		local flying = airborne(Vector3.zero)
		flying:faceToward(Vector3.new(10, -20, 0), math.huge)
		Fixtures.expectNear(flying.forward, Vector3.xAxis)
	end)

	it("turns the speed across the surface toward a strike's way, keeping it and the rise", function()
		Fixtures.expectNear(
			skater(Vector3.new(0, 0, -30)):turnChange(Vector3.new(10, 0, 0), math.huge),
			Vector3.new(30, 0, 30)
		)
		-- 30°: (0, 0, -30) becomes (15.000, 0, -25.981).
		Fixtures.expectNear(
			skater(Vector3.new(0, 0, -30)):turnChange(Vector3.new(10, 0, 0), math.rad(30)),
			Vector3.new(15.000, 0, 4.019)
		)
		Fixtures.expectNear(
			airborne(Vector3.new(0, 20, -30)):turnChange(Vector3.xAxis, math.huge),
			Vector3.new(30, 0, 30)
		)
		Fixtures.expectNear(skater(Vector3.zero):turnChange(Vector3.xAxis, math.huge), Vector3.zero)
	end)

	it(
		"homes along the surface on the ground and in 3D in the air: an Uppercut's leap tilts toward a target",
		function()
			Fixtures.expectNear(
				skater(Vector3.new(0, 0, -30)):homeChange(Vector3.new(10, 5, 0), math.huge),
				Vector3.new(30, 0, 30)
			)
			-- (0, 50, 0) turned 30° toward (0, 30, -30): (0, 43.301, -25.000).
			Fixtures.expectNear(
				airborne(Vector3.new(0, 50, 0)):homeChange(Vector3.new(0, 30, -30), math.rad(30)),
				Vector3.new(0, -6.699, -25.000)
			)
			Fixtures.expectNear(
				airborne(Vector3.new(0, 50, 0)):homeChange(Vector3.new(0, 30, -30), math.huge),
				Vector3.new(0, -14.645, -35.355)
			)
			Fixtures.expectNear(airborne(Vector3.zero):homeChange(Vector3.xAxis, math.huge), Vector3.zero)
		end
	)

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
		falling:step(input({ knockdown = "Hit" }), ground(FLAT, 0, false), 0.1)
		Fixtures.expectNear(falling.velocity * Vector3.new(1, 0, 1), Vector3.new(0, 0, -59.88))
		expect(falling.velocity.Y).toBeCloseTo(-19.62 * (1 - 0.02 * 0.1), 3)
	end)
end)

-- The owner (#252, Q24): RC's knockdowns slow evenly to a stop in a set time, whatever the speed: a tackle 50 -> 0 km/h
-- and posed falls 70 -> 0 and 57 -> 0 in 1.5 s each, dives 68 -> 0 in 0.7 s and 84 -> 10 in 0.8 s (Videos 4-7).
describe("SkateMath knockdown slides", function()
	local DT = 1 / 60
	local KINDS: { Attributes.Knockdown } = { "Hit", "Fall", "Dive" }

	it("slows each kind evenly to a stop in its own time, whatever the speed", function()
		for _, kind in KINDS do
			local thirdSteps = math.round(movement.knockdownSlideSeconds[kind] * 60 / 3)
			for _, speed in { 80, 30 } do
				local s = skater(Vector3.new(0, 0, -speed))
				local down = input({ knockdown = kind })
				-- A third of the time: two thirds of the speed left; two thirds: a third; then none.
				for third = 1, 3 do
					for _ = 1, thirdSteps do
						s:step(down, ground(), DT)
					end
					expect(s.velocity.Magnitude).toBeCloseTo(speed * (1 - third / 3), 3)
				end
				Fixtures.expectNear(s.forward, -Vector3.zAxis)
				-- Still stopped while down.
				s:step(down, ground(), DT)
				Fixtures.expectNear(s.velocity, Vector3.zero)
			end
		end
		-- A step longer than the whole slide stops the skater at zero, never backwards.
		local s = skater(Vector3.new(0, 0, -10))
		s:step(input({ knockdown = "Dive" }), ground(), 1)
		Fixtures.expectNear(s.velocity, Vector3.zero)
	end)

	it("times a slide from its first step on the ground, afresh for each knockdown", function()
		local halfSteps = math.round(movement.knockdownSlideSeconds.Hit * 60 / 2)
		local down = input({ knockdown = "Hit" })
		local function slideHalf(s: SkateMath.Skater): number
			s.velocity = Vector3.new(0, 0, -60)
			for _ = 1, halfSteps do
				s:step(down, ground(), DT)
			end
			return s.velocity.Magnitude
		end
		-- Knocked down in the air first: the time starts at the touchdown.
		local s = skater(Vector3.new(0, 0, -60))
		s.mode = "Airborne"
		for _ = 1, 30 do
			s:step(down, ground(FLAT, 0, false), DT)
		end
		s.mode = "Grounded"
		expect(slideHalf(s)).toBeCloseTo(30, 3)
		-- Up for a step, then down again: a new slide.
		s:step(input(), ground(), DT)
		expect(slideHalf(s)).toBeCloseTo(30, 3)
	end)

	it("stops in its time down a slope too, and lies still there until up", function()
		local s = skater(DOWNHILL * 20)
		local down = input({ knockdown = "Hit" })
		for _ = 1, math.round(movement.knockdownSlideSeconds.Hit * 60) do
			s:step(down, ground(SLOPE), DT)
		end
		Fixtures.expectNear(s.velocity, Vector3.zero)
		for _ = 1, 30 do
			s:step(down, ground(SLOPE), DT)
		end
		Fixtures.expectNear(s.velocity, Vector3.zero)
	end)
end)

-- The owner's re-playtest (#255): the arena's curves are flat strips. The ground does no work on a skater, so the speed
-- along it turns with each strip's small turn, as on the curve the strips stand for; only a sharper turn, a corner,
-- takes the speed into its new face. Projecting the speed onto each strip lost ~12% of it per wall visit.
describe("SkateMath on curves", function()
	local DT = 1 / 60
	local lossless = table.clone(movement)
	lossless.rollingFriction = 0
	lossless.airDrag = 0

	-- A face tilted `deg` about X: rising toward +Z for a positive angle.
	local function face(deg: number): Vector3
		return Vector3.new(0, math.cos(math.rad(deg)), -math.sin(math.rad(deg)))
	end

	it("keeps its speed through a strip of a curve, and loses the speed into a corner", function()
		local s = SkateMath.new(lossless, Fixtures.GRAVITY)
		s.velocity = Vector3.new(0, 0, 60)
		s:step(input(), ground(), DT)
		s:step(input(), ground(face(15)), DT)
		-- 60 − 196.2 × sin 15° / 60 (projected onto the strip it would have been 60 × cos 15° = 57.96 first).
		expect(s.velocity.Magnitude).toBeCloseTo(59.154, 2)
		-- Down a face falling 20°, then up one rising 20°: a 40° corner. One step down: 60 + 196.2 × sin 20° / 60 =
		-- 61.118; then 61.118 × cos 40° − 1.118 up the new face.
		local cornered = SkateMath.new(lossless, Fixtures.GRAVITY)
		cornered.velocity = Vector3.new(0, -math.sin(math.rad(20)), math.cos(math.rad(20))) * 60
		cornered:step(input(), ground(face(-20)), DT)
		cornered:step(input(), ground(face(20)), DT)
		expect(cornered.velocity.Magnitude).toBeCloseTo(45.701, 2)
	end)

	-- A bank of radius 16 in six 15° strips (like the middle's inner bank) between the floor and an upright wall.
	local RADIUS = 16
	local STRIP = math.rad(15)
	local function bank(p: Vector3): Types.Ground
		if p.Z <= 0 then
			return ground(FLAT, p.Y)
		end
		local around = math.atan2(p.Z, RADIUS - p.Y)
		if around >= math.pi / 2 then
			return ground(Vector3.new(0, 0, -1), RADIUS - p.Z)
		end
		local k = math.clamp(math.floor(around / STRIP), 0, 5)
		local middle = (k + 0.5) * STRIP
		local normal = Vector3.new(0, math.cos(middle), -math.sin(middle))
		local start = Vector3.new(p.X, RADIUS - RADIUS * math.cos(k * STRIP), RADIUS * math.sin(k * STRIP))
		return ground(normal, (p - start):Dot(normal))
	end

	it("comes back from a bank of strips at the speed it left with, nothing slowing it", function()
		local s = SkateMath.new(lossless, Fixtures.GRAVITY)
		local p = Vector3.new(0, lossless.hoverHeight, -30)
		s.velocity = Vector3.new(0, 0, 60)
		s.forward = Vector3.zAxis
		local top = 0
		for _ = 1, 600 do
			s:step(input(), bank(p), DT)
			p += s.velocity * DT
			top = math.max(top, p.Y)
			if p.Z < -30 then
				break
			end
		end
		-- Well up the strips, and back on the floor.
		expect(s.mode).toBe("Grounded")
		expect(top).toBeGreaterThan(RADIUS / 2)
		expect(p.Z < -30).toBe(true)
		expect(s.velocity.Magnitude).toBeCloseTo(60, 0)
	end)
end)

-- The owner (#258, Q27, Q28, Videos 10-11): a skater in the air who touches a ride surface lands on it feet first;
-- one who leaves a wall along it (an Uppercut up the glass) keeps every air action on the way up, then comes back onto
-- it once falling, while it is in reach and they are not moving away from it.
describe("SkateMath landing on what they touch", function()
	local DT = 1 / 60
	-- Upright, facing -X: the skater rides its -X side.
	local WALL = Vector3.new(-1, 0, 0)

	local function flyer(velocity: Vector3): SkateMath.Skater
		local s = skater(velocity)
		s.mode = "Airborne"
		return s
	end

	it("lands on a wall it flies into, feet first, losing only the speed into it", function()
		local s = flyer(Vector3.new(30, -10, 5))
		expect(s:touch(WALL, input())).toBe(true)
		expect(s.mode).toBe("Grounded")
		Fixtures.expectNear(s.up, WALL)
		Fixtures.expectNear(s.velocity, Vector3.new(0, -10, 5))
		s:step(input(), ground(WALL), DT)
		expect(s.mode).toBe("Grounded")
		-- Moving away from it, a touch is nothing.
		local leaving = flyer(Vector3.new(-5, 0, 0))
		expect(leaving:touch(WALL, input())).toBe(false)
		expect(leaving.mode).toBe("Airborne")
	end)

	it("only blocks under an overhang, and on the ground", function()
		local s = flyer(Vector3.new(5, 20, 0))
		expect(s:touch(Vector3.new(0, -1, 0), input())).toBe(true)
		expect(s.mode).toBe("Airborne")
		Fixtures.expectNear(s.velocity, Vector3.new(5, 0, 0))
		-- A lip's first strip leans 22.5° past upright: an overhang too.
		local lip = Vector3.new(-math.cos(math.rad(22.5)), -math.sin(math.rad(22.5)), 0)
		local under = flyer(Vector3.new(20, 0, 0))
		under:touch(lip, input())
		expect(under.mode).toBe("Airborne")
		-- One met still rising never catches them: falling, they look along the feet (#267).
		local rising = flyer(Vector3.new(20, 20, 0))
		rising:touch(lip, input())
		expect(rising.velocity.Y).toBeGreaterThan(0)
		rising.velocity = Vector3.new(0, -5, 0)
		Fixtures.expectNear(rising:groundRay(), -rising.up)
		local riding = skater(Vector3.new(30, 0, 0))
		riding:touch(WALL, input())
		expect(riding.mode).toBe("Grounded")
		Fixtures.expectNear(riding.up, FLAT)
		Fixtures.expectNear(riding.velocity, Vector3.zero)
	end)

	it("never touches down on an overhang its feet find", function()
		local s = flyer(Vector3.new(0, 5, 0))
		s.up = Vector3.new(0, -1, 0)
		s:step(input(), ground(Vector3.new(0, -1, 0)), DT)
		expect(s.mode).toBe("Airborne")
	end)

	it("touches a wall down on the belly while posing or diving, as any touchdown", function()
		local posed = flyer(Vector3.new(30, -40, 0))
		posed.airPosing = true
		posed:touch(WALL, input({ jumpHeld = true }))
		expect(posed.landedPosed).toBe(true)
		-- (0, −40, 0) once the speed into the wall is lost, then bellyLandingKeep of it.
		Fixtures.expectNear(posed.velocity, Vector3.new(0, -40 * movement.bellyLandingKeep, 0))
		local diver = flyer(Vector3.new(30, -40, 0))
		diver:touch(WALL, input({ diving = true }))
		expect(diver.landedPosed).toBe(false)
		Fixtures.expectNear(diver.velocity, Vector3.new(0, -40 * movement.bellyLandingKeep, 0))
	end)

	it("flies up along the wall it leaps from, looking toward it, and comes back onto it once falling", function()
		local s = skater(Vector3.new(0, 30, 0))
		s:step(input(), ground(WALL), DT)
		s:push(Vector3.yAxis * 110, true)
		expect(s.mode).toBe("Airborne")
		local frames = 0
		while s.velocity.Y > 0 and frames < 120 do
			-- Rising, the ray looks toward the wall, whose grip keeps them by it (#289) but which lands no one on the
			-- way up (Q28).
			Fixtures.expectNear(s:groundRay(), -WALL)
			s:step(input(), ground(WALL), DT)
			expect(s.mode).toBe("Airborne")
			frames += 1
		end
		Fixtures.expectNear(s:groundRay(), -WALL)
		-- Found within the ray's reach, though further than hoverHeight: caught.
		s:step(input(), ground(WALL, movement.hoverHeight + 1), DT)
		expect(s.mode).toBe("Grounded")
		Fixtures.expectNear(s.up, WALL)
	end)

	-- Measured in Play (#258): riding the outer wall's foot up to 0.08 studs closer than hoverHeight, the hover pushed
	-- the skater off it at up to 1.5 studs/s, and a leap that kept that push was still moving off the wall at its top.
	it("leaps up a wall without the hover's push off it, so the wall catches it at the top", function()
		local s = skater(Vector3.new(0, 30, 0))
		s:step(input(), ground(WALL, movement.hoverHeight - 0.08), DT)
		expect(s.velocity:Dot(WALL)).toBeGreaterThan(1)
		s:push(Vector3.yAxis * 60, true)
		expect(math.abs(s.velocity:Dot(WALL))).toBeLessThan(1e-6)
		local frames = 0
		while s.mode == "Airborne" and frames < 120 do
			s:step(input(), ground(WALL), DT)
			frames += 1
		end
		expect(s.mode).toBe("Grounded")
		Fixtures.expectNear(s.up, WALL)
	end)

	-- Video 30 (#289's trial): an Uppercut off the outer wall's curved foot, 8° short of upright, leaps up into the
	-- upright wall above. That wall bends toward them: it meets them (touch), and their flight beside it never turns
	-- them off it.
	it("keeps a leap off a wall's curved foot moving into the upright wall above it", function()
		local foot = Vector3.new(-math.cos(math.rad(8)), math.sin(math.rad(8)), 0)
		local s = skater(Vector3.zero)
		s.up = foot
		s:step(input(), ground(foot), DT)
		s.velocity = Vector3.new(math.sin(math.rad(8)), math.cos(math.rad(8)), 0) * 25
		-- The Uppercut's leap: 110 × √(2/3) (#279).
		s:push(Vector3.yAxis * 89.81, true)
		s:step(input(), ground(WALL), DT)
		expect(s.mode).toBe("Airborne")
		-- 25 × sin 8° = 3.479 into it, less one air step's drag (× (1 − 0.02 / 60)): 3.478.
		expect(s.velocity.X).toBeCloseTo(3.478, 3)
	end)

	-- RC (#267, Video 14, 4.0-7.4 s): Jump while riding up the glass rose along it and the glass took them back.
	it("jumps up a wall it rides without the hover's push off it, and the wall catches it once falling", function()
		local s = skater(Vector3.new(0, 0, -20))
		s:step(input(), ground(WALL, movement.hoverHeight - 0.08), DT)
		expect(s.velocity:Dot(WALL)).toBeGreaterThan(1)
		s:step(input({ jump = true }), ground(WALL, movement.hoverHeight - 0.08), DT)
		expect(s.mode).toBe("Airborne")
		expect(math.abs(s.velocity:Dot(WALL))).toBeLessThan(1e-6)
		local frames = 0
		while s.mode == "Airborne" and frames < 120 do
			s:step(input(), ground(WALL), DT)
			frames += 1
		end
		expect(s.mode).toBe("Grounded")
		Fixtures.expectNear(s.up, WALL)
	end)

	-- RC (#267, Video 14, 55.2-57.6 s): jumping from the floor straight at the wall, the speed into it was lost and
	-- the skater went up the glass still in the air, back onto it ~1.2 s later; Jump only came back then.
	it("slides up a wall it meets while rising, and lands on it only once falling", function()
		local s = flyer(Vector3.new(30, 40, 0))
		s.airPoseReady = false
		expect(s:touch(WALL, input())).toBe(true)
		expect(s.mode).toBe("Airborne")
		Fixtures.expectNear(s.velocity, Vector3.new(0, 40, 0))
		local frames = 0
		while s.mode == "Airborne" and frames < 120 do
			local towardWall = s:groundRay():Dot(-WALL) > 0.999
			s:step(input(), if towardWall then ground(WALL, 1) else ground(FLAT, 0, false), DT)
			frames += 1
		end
		-- Rising for 40 / 196.2 = 0.204 s first: 12 frames.
		expect(frames).toBeGreaterThanOrEqual(12)
		expect(s.mode).toBe("Grounded")
		Fixtures.expectNear(s.up, WALL)
		expect(s.airPoseReady).toBe(true)
		-- Its feet finding a wall on the way up do not land it either; a gentle bank met rising still does.
		local feet = flyer(Vector3.new(0, 20, 0))
		feet:step(input(), ground(WALL), DT)
		expect(feet.mode).toBe("Airborne")
		local bank = flyer(Vector3.new(0, 5, 40))
		expect(bank:touch(SLOPE, input())).toBe(true)
		expect(bank.mode).toBe("Grounded")
	end)

	it("keeps the velocity off the surface in every push but a launch off the ground", function()
		-- A lunge on the ground keeps the hover's pull: the pushes keep the velocity off their plane.
		local riding = skater(Vector3.new(0, 0, -30))
		riding:step(input(), ground(FLAT, movement.hoverHeight - 0.08), DT)
		local pull = riding.velocity.Y
		expect(pull).toBeGreaterThan(1)
		riding:push(Vector3.new(0, 0, -10), false)
		expect(riding.velocity.Y).toBe(pull)
		-- A leap in the air keeps the fall it adds to, and one from behind a leader the leader's velocity.
		local flying = skater(Vector3.new(20, -10, 0))
		flying.mode = "Airborne"
		flying:push(Vector3.yAxis * 50, true)
		Fixtures.expectNear(flying.velocity, Vector3.new(20, 40, 0))
		local attached = skater(Vector3.zero)
		attached:follow(Vector3.zero, Vector3.zero, Vector3.new(0, -10, -30), -Vector3.zAxis)
		attached:push(Vector3.yAxis * 50, true)
		Fixtures.expectNear(attached.velocity, Vector3.new(0, 40, -30))
	end)

	-- The arena's glass reads up to 6.5e-5 rad past upright (measured, #234): falling beside it reads as moving off it.
	it("comes back onto glass leaning past upright by float noise", function()
		local lean = 6.5e-5
		local glass = Vector3.new(-math.cos(lean), -math.sin(lean), 0)
		local s = skater(Vector3.new(0, 30, 0))
		s.up = glass
		s:step(input(), ground(glass), DT)
		s:push(Vector3.yAxis * 60, true)
		local frames = 0
		while s.mode == "Airborne" and frames < 120 do
			s:step(input(), ground(glass), DT)
			frames += 1
		end
		expect(s.mode).toBe("Grounded")
	end)

	-- The middle glass's round ends (#289): the outside of an upright pillar of radius 20, built as flat strips 3.75°
	-- apart (the arena's stations). The face beside a root, and what the controller's ray from it finds: that face, at
	-- the ray's length to its plane (20 × cos 1.875° from the axis).
	local PILLAR_STRIP = math.rad(3.75)
	local PILLAR_FACES = 20 * math.cos(PILLAR_STRIP / 2)
	local function pillarFace(position: Vector3): Vector3
		local facing = (math.floor(math.atan2(position.Z, position.X) / PILLAR_STRIP) + 0.5) * PILLAR_STRIP
		return Vector3.new(math.cos(facing), 0, math.sin(facing))
	end
	local function pillarGround(position: Vector3, direction: Vector3): Types.Ground
		local normal = pillarFace(position)
		local toward = -direction:Dot(normal)
		local reach = if toward > Vectors.EPSILON then (position:Dot(normal) - PILLAR_FACES) / toward else math.huge
		return ground(normal, reach, reach <= movement.groundProbeLength)
	end

	-- Riding the pillar's first strip drifting `round` studs/s round it, the skater leaps 60 up it (an action's
	-- launch), moving `off` studs/s off it, and flies on, each step finding the ground its own ray looks for. Says how
	-- far the root strayed from hoverHeight off the face while rising, the skater once caught (or after two seconds),
	-- and where it is then.
	local function leapRoundPillar(round: number, off: number?): (number, SkateMath.Skater, Vector3)
		local first = Vector3.new(math.cos(PILLAR_STRIP / 2), 0, math.sin(PILLAR_STRIP / 2))
		local along = Vector3.new(-first.Z, 0, first.X)
		local position = first * (PILLAR_FACES + movement.hoverHeight) - along * 0.6
		local s = skater(along * round)
		s.up = first
		s:step(input(), pillarGround(position, -s.up), DT)
		position += s.velocity * DT
		s:push(Vector3.yAxis * 60 + first * (off or 0), true)
		local stray = 0
		for _ = 1, 120 do
			local rising = s.velocity.Y > 0
			s:step(input(), pillarGround(position, (s:groundRay())), DT)
			position += s.velocity * DT
			if s.mode == "Grounded" then
				break
			end
			if rising then
				local away = position:Dot(pillarFace(position)) - PILLAR_FACES
				stray = math.max(stray, math.abs(away - movement.hoverHeight))
			end
		end
		return stray, s, position
	end

	-- The owner (#289, Q71): a leap up the middle glass's round ends keeps by the glass while drifting slowly round it
	-- (15² / 22.5 = 10, within the grip's 38), and the glass catches them feet first once falling. Drifting round it at
	-- riding speed lets go of them (35² / 22.5 = 54).
	it("keeps a leap up a round pillar by it while drifting slowly round it, and catches it once falling", function()
		local stray, s, position = leapRoundPillar(15)
		expect(stray).toBeLessThan(0.1)
		expect(s.mode).toBe("Grounded")
		expect(s.velocity.Y).toBeLessThan(0)
		Fixtures.expectNear(s.up, pillarFace(position))
		local _, fast = leapRoundPillar(35)
		expect(fast.mode).toBe("Airborne")
		Fixtures.expectNear(fast:groundRay(), -fast.up)
		-- The grip turns only their speed along it: drifting off it at 1 stud/s they keep drifting off, 0.29 studs by
		-- the top (56.7 up at 196.2), and nothing catches a skater moving off the glass.
		local drift, drifting = leapRoundPillar(15, 1)
		expect(drift).toBeGreaterThan(0.2)
		expect(drifting.mode).toBe("Airborne")
	end)

	-- Only near-upright walls grip a flight beside them (#289): gravity presses a skater onto one 70° from flat harder
	-- than the grip (196.2 × cos 70° = 67), and in the air nothing presses them, so a flight beside it is free.
	it("flies free beside a wall that gravity presses harder than the grip, as with no wall near", function()
		local steep = Vector3.new(-math.sin(math.rad(70)), math.cos(math.rad(70)), 0)
		local s = skater(Vector3.zero)
		s.up = steep
		for _ = 1, 10 do
			s.velocity = Vector3.new(0, 0, 20)
			s:step(input(), ground(steep), DT)
		end
		s.velocity = Vector3.new(0, 0, 20)
		s:push(Vector3.yAxis * 30, true)
		local free = flyer(s.velocity)
		-- Its face turned 3.75° round, away from them (they drift along +Z).
		s:step(input(), ground(CFrame.Angles(0, math.rad(3.75), 0) * steep), DT)
		free:step(input(), ground(FLAT, 0, false), DT)
		Fixtures.expectNear(s.velocity, free.velocity)
	end)

	-- A ray that found nothing says nothing (Types.Ground): rising beside the wall they leap along while drifting along
	-- it, a miss whose leftover normal is turned 20° round either way neither turns their flight nor stays as the
	-- wall's last normal, so back beside the wall nothing has turned (#289).
	it("ignores the normal of a ground ray that found nothing, beside the wall it leaps along", function()
		for _, round in { 20, -20 } do
			local s = skater(Vector3.new(0, 30, 0))
			s:step(input(), ground(WALL), DT)
			s:push(Vector3.new(0, 80, 20), true)
			local free = flyer(s.velocity)
			s:step(input(), ground(CFrame.Angles(0, math.rad(round), 0) * WALL, 1, false), DT)
			free:step(input(), ground(FLAT, 0, false), DT)
			Fixtures.expectNear(s.velocity, free.velocity)
			s:step(input(), ground(WALL), DT)
			Fixtures.expectNear(s:groundRay(), -WALL)
		end
	end)

	-- The owner (Q28): "both": on a leap up the glass every air action works, and the glass catches them.
	it("keeps the air on a leap up the wall, and a pose held into its catch is a fall", function()
		local s = skater(Vector3.new(0, 30, 0))
		s:step(input(), ground(WALL), DT)
		s:push(Vector3.yAxis * 110, true)
		-- Drifting into the wall on the way up, it only slides along it.
		s.velocity += -WALL * 5
		expect(s:touch(WALL, input())).toBe(true)
		expect(s.mode).toBe("Airborne")
		Fixtures.expectNear(s.velocity, Vector3.new(0, s.velocity.Y, 0))
		s:step(input({ jump = true, jumpHeld = true }), ground(WALL), DT)
		expect(s.airPosing).toBe(true)
		local frames = 0
		while s.mode == "Airborne" and frames < 180 do
			s:step(input({ jumpHeld = true }), ground(WALL), DT)
			frames += 1
		end
		expect(s.mode).toBe("Grounded")
		expect(s.landedPosed).toBe(true)
		Fixtures.expectNear(s.up, WALL)
	end)

	it("never catches a skater moving away from the wall they left, or out of its reach", function()
		-- Off it with nothing in reach, then moving away from it at 20 studs/s (a lunge, say), already falling.
		local leaver = skater(Vector3.new(0, -5, 0))
		leaver:step(input(), ground(WALL), DT)
		leaver:step(input(), ground(WALL, 0, false), DT)
		expect(leaver.mode).toBe("Airborne")
		leaver.velocity += WALL * 20
		Fixtures.expectNear(leaver:groundRay(), -WALL)
		leaver:step(input(), ground(WALL, 4), DT)
		expect(leaver.mode).toBe("Airborne")
		-- It no longer looks for the wall.
		Fixtures.expectNear(leaver:groundRay(), -leaver.up)
		-- Falling beside it with nothing in reach.
		local beside = skater(Vector3.new(0, -5, 0))
		beside:step(input(), ground(WALL), DT)
		beside:step(input(), ground(WALL, 0, false), DT)
		expect(beside.mode).toBe("Airborne")
		Fixtures.expectNear(beside:groundRay(), -WALL)
		beside:step(input(), ground(WALL, 0, false), DT)
		Fixtures.expectNear(beside:groundRay(), -beside.up)
	end)

	it("forgets the wall it left once it lands elsewhere, or holds on behind a leader", function()
		-- Up off the wall, then falling into another wall.
		local OTHER = Vector3.new(0, 0, -1)
		local s = skater(Vector3.new(0, 30, 0))
		s:step(input(), ground(WALL), DT)
		s:push(Vector3.yAxis * 80, true)
		s.velocity = Vector3.new(0, -5, 20)
		expect(s:touch(OTHER, input())).toBe(true)
		expect(s.mode).toBe("Grounded")
		-- Sliding down the other wall, the ray looks along the feet, into it.
		s.velocity = Vector3.new(0, -5, 0)
		Fixtures.expectNear(s:groundRay(), -OTHER)
		-- Up off the wall, turning upright on the way, then behind a leader and let go.
		local follower = skater(Vector3.new(0, 30, 0))
		follower:step(input(), ground(WALL), DT)
		follower:push(Vector3.yAxis * 80, true)
		for _ = 1, 10 do
			follower:step(input(), ground(FLAT, 0, false), DT)
		end
		follower:follow(Vector3.zero, Vector3.zero, Vector3.zero, -Vector3.zAxis)
		follower:release(Vector3.zero)
		follower.velocity = Vector3.new(0, -5, 0)
		Fixtures.expectNear(follower:groundRay(), -follower.up)
	end)

	it("never looks back toward an overhang it fell from", function()
		-- A lip's first strip, 22.5° past upright, lets go of a skater with no curve to hold them.
		local lip = Vector3.new(-math.cos(math.rad(22.5)), -math.sin(math.rad(22.5)), 0)
		local s = skater(Vector3.new(0, 0, 5))
		s.up = lip
		s:step(input(), ground(lip), DT)
		expect(s.mode).toBe("Airborne")
		expect(s.velocity.Y).toBeLessThan(0)
		Fixtures.expectNear(s:groundRay(), -s.up)
	end)

	it("looks along the feet after leaving the floor, and lands on it only within hoverHeight", function()
		local s = skater(Vector3.new(0, 0, -20))
		s:step(input({ jump = true }), ground(), DT)
		expect(s.mode).toBe("Airborne")
		s.velocity = Vector3.new(0, -10, -20)
		Fixtures.expectNear(s:groundRay(), -s.up)
		s:step(input(), ground(FLAT, movement.hoverHeight + 1), DT)
		expect(s.mode).toBe("Airborne")
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

	-- Straight over the corner, and slantwise (45° along it): a corner says nothing of the way a curve bends (#289),
	-- so the window counts the whole path either way.
	it("lets go of a flat ceiling once the corner that led onto it is behind, at any speed or slant", function()
		local wall, ceiling = Vector3.new(-1, 0, 0), Vector3.new(0, -1, 0)
		local speed = movement.hardCap
		for _, slant in { 0, math.rad(45) } do
			local over, along = speed * math.cos(slant), speed * math.sin(slant)
			local s = skater(Vector3.zero)
			for _ = 1, 10 do
				s.velocity = Vector3.new(0, over, along)
				s:step(input(), ground(wall), DT)
			end
			s.velocity = Vector3.new(-over, 0, along)
			s:step(input(), ground(ceiling), DT)
			-- The corner's turn is still within the window: the skater holds for now.
			expect(s.mode).toBe("Grounded")
			local frames = 0
			while s.mode == "Grounded" and frames < 60 do
				s.velocity = Vector3.new(-over, 0, along)
				s:step(input(), ground(ceiling), DT)
				frames += 1
			end
			expect(s.mode).toBe("Airborne")
			-- Within the window plus a frame's travel (hardCap × DT, about 2 studs).
			expect(frames * speed * DT).toBeLessThan(movement.curvatureWindow + speed * DT + 1e-6)
		end
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

-- The owner (#257, Q26): real physics, a surface only pushes. A skater stays on only while the push their path's curve
-- needs, speed² × curvature, reaches how firmly the surface presses them on: gravity's push into it, and on a wall that
-- holds at least wallGrip (#289, Q71). Where the surface bends away from them the curvature is negative: an upright
-- wall bending away holds only a slow drift round it, and a crest throws off a skater too fast for gravity to keep on
-- it. Curves bending toward them hold, as before. Only the speed the way the surface bends follows its curve.
describe("SkateMath on surfaces that bend away", function()
	local DT = 1 / 60

	-- Rides an arc of `radius` from `from` to `to` (radians), one step per DT, the velocity set along it each step, and
	-- says whether the skater stayed on. `normalAt` and `alongAt` give the surface's normal and the way along it at an
	-- angle. The skater first rides the surface the arc starts from. With `sideways`, they also move that fast along Z,
	-- across the arc (a slanted crossing).
	local function staysOn(
		speed: number,
		radius: number,
		from: number,
		to: number,
		normalAt: (number) -> Vector3,
		alongAt: (number) -> Vector3,
		sideways: number?
	): boolean
		local side = Vector3.zAxis * (sideways or 0)
		local s = skater(Vector3.zero)
		for _ = 1, 10 do
			s.velocity = alongAt(from) * speed + side
			s:step(input(), ground(normalAt(from)), DT)
		end
		local step = speed * DT / radius
		for frame = 0, math.ceil((to - from) / step) do
			local at = from + frame * step
			s.velocity = alongAt(at) * speed + side
			s:step(input(), ground(normalAt(at)), DT)
			if s.mode == "Airborne" then
				return false
			end
		end
		return true
	end

	-- Over a crest, moving +X: the top at 0, the surface falling away ahead.
	local function crestNormal(phi: number): Vector3
		return Vector3.new(math.sin(phi), math.cos(phi), 0)
	end
	local function crestAlong(phi: number): Vector3
		return Vector3.new(math.cos(phi), -math.sin(phi), 0)
	end
	-- Up a quarter-pipe from the floor (0) to upright (pi / 2), moving +X then up.
	local function pipeNormal(phi: number): Vector3
		return Vector3.new(-math.sin(phi), math.cos(phi), 0)
	end
	local function pipeAlong(phi: number): Vector3
		return Vector3.new(math.cos(phi), math.sin(phi), 0)
	end

	-- Round the outside of an upright pillar of radius 20 (like the middle glass's round ends), built as flat strips
	-- 3.75° apart (the arena's stations), the velocity set each frame: `round` studs/s round it and `rise` up it. The
	-- skater rides the first strip, then the face turns away from them. Says the frame they left it at (nil if they
	-- never did in `frames`) and the frame its face first turned.
	local function roundPillar(round: number, rise: number, frames: number): (number?, number?)
		local RADIUS, STRIP = 20, math.rad(3.75)
		local s = skater(Vector3.zero)
		local around = 0
		local firstTurn: number? = nil
		for frame = 1, frames do
			local strip = math.floor(around / STRIP)
			if strip > 0 and firstTurn == nil then
				firstTurn = frame
			end
			local facing = (strip + 0.5) * STRIP
			s.velocity = Vector3.new(-math.sin(around), 0, math.cos(around)) * round + Vector3.yAxis * rise
			s:step(input(), ground(Vector3.new(math.cos(facing), 0, math.sin(facing))), DT)
			if s.mode == "Airborne" then
				return frame, firstTurn
			end
			around += round * DT / RADIUS
		end
		return nil, firstTurn
	end

	-- Gravity presses nothing onto an upright wall; its grip does (the owner, #289, Q71): round the pillar it holds a
	-- drift up to √(38 × 20) = 27.6 studs/s, and a faster one flies off at the first turn.
	it("keeps a slow drift round an upright pillar, and flies off a faster one at its first turn", function()
		for _, round in { 10, 20 } do
			expect((roundPillar(round, 0, 120))).toBeNil()
		end
		for _, round in { 35, 60, movement.hardCap } do
			local leftAt, firstTurn = roundPillar(round, 0, 120)
			expect(firstTurn).never.toBeNil()
			expect(leftAt).toBe(firstTurn)
		end
	end)

	-- Only the drift round it follows the pillar's bend (#289): rising or falling along it while drifting 20 round, the
	-- path bends by 20² / 20 = 20 studs/s², within the grip (read per stud of the whole path, 82.5 at 80 up: let go).
	it("keeps a slow drift round an upright pillar however fast the skater rises or falls along it", function()
		for _, rise in { 10, 80, -80 } do
			expect((roundPillar(20, rise, 120))).toBeNil()
		end
	end)

	-- A crest of radius 20, from 15° before its top to 15° past it: gravity keeps a skater on only while speed² / 20
	-- stays within 196.2 × cos 15° = 189.5, up to 61.6 studs/s.
	it("throws a skater too fast for gravity off a crest, and keeps a slower one on", function()
		local edge = math.rad(15)
		expect(staysOn(57, 20, -edge, edge, crestNormal, crestAlong)).toBe(true)
		expect(staysOn(66, 20, -edge, edge, crestNormal, crestAlong)).toBe(false)
	end)

	-- Off a surface its curve is forgotten, the way it bent included (#289): a skater who drifted round a pillar's face
	-- (bending along Z) and flew off counts their whole road again riding along X, so a 15° crest at 30 studs/s holds
	-- them (29² × 15° over the 10-stud window: 22, within gravity's 189.5).
	it("forgets the way a surface bent once off it, counting the next ride's whole road", function()
		local pillar = Vector3.xAxis
		local s = skater(Vector3.zero)
		s.up = pillar
		for _ = 1, 5 do
			s.velocity = Vector3.new(0, 0, 10)
			s:step(input(), ground(pillar), DT)
		end
		s.velocity = Vector3.new(0, 0, 10)
		s:step(input(), ground(CFrame.Angles(0, -math.rad(3.75), 0) * pillar), DT)
		-- Off its edge, then down onto the floor.
		s:step(input(), ground(FLAT, 0, false), DT)
		s.velocity = Vector3.new(30, -1, 0)
		s:step(input(), ground(), DT)
		expect(s.mode).toBe("Grounded")
		for _ = 1, 10 do
			s.velocity = Vector3.new(30, 0, 0)
			s:step(input(), ground(), DT)
		end
		s.velocity = Vector3.new(30, 0, 0)
		s:step(input(), ground(Vector3.new(math.sin(math.rad(15)), math.cos(math.rad(15)), 0)), DT)
		expect(s.mode).toBe("Grounded")
	end)

	-- Thrown off a surface with no wall to come back to, the path's curve is forgotten at once (#289 keeps it only by a
	-- wall that holds): touching down the very next step loses the speed into the new face, as any touchdown.
	it("forgets the curve of a crest it is thrown off, so a touchdown the next step is like any other", function()
		local s = skater(Vector3.zero)
		for _ = 1, 10 do
			s.velocity = Vector3.new(80, 0, 0)
			s:step(input(), ground(), DT)
		end
		s.velocity = Vector3.new(80, 0, 0)
		-- 80 × cos 25° = 72.5 over a 25° crest read across the 10-stud window: 72.5² × 0.436 / 10.5 = 218, past
		-- gravity's 177.8.
		s:step(input(), ground(Vector3.new(math.sin(math.rad(25)), math.cos(math.rad(25)), 0)), DT)
		expect(s.mode).toBe("Airborne")
		local twin = skater(s.velocity)
		twin.mode = "Airborne"
		s:step(input(), ground(), DT)
		twin:step(input(), ground(), DT)
		expect(s.mode).toBe("Grounded")
		Fixtures.expectNear(s.velocity, twin.velocity)
	end)

	-- Crossing it slantwise, only the speed across the crest follows its curve (#289): 80 studs/s at 45° crosses at
	-- 56.6, needing 56.6² / 20 = 160, within gravity's 189.5 (read per stud of the whole path, 226: thrown off).
	it("keeps a skater crossing a crest slantwise on while the speed across it is slow enough", function()
		local edge = math.rad(15)
		local across = 80 * math.cos(math.rad(45))
		expect(staysOn(across, 20, -edge, edge, crestNormal, crestAlong, across)).toBe(true)
	end)

	-- The outer wall's foot (radius 18) bends toward the skater: it pushes harder the faster they go.
	it("keeps a skater on a curve that bends toward them, however fast or slow", function()
		for _, speed in { 8, 60, movement.hardCap } do
			expect(staysOn(speed, 18, 0, math.pi / 2, pipeNormal, pipeAlong)).toBe(true)
		end
	end)

	-- Built faces lean a hair (up to 6.5e-5 rad, measured, #234), so a ray crossing from face to face reads a turn of
	-- float noise, not a curve: a skater along the glass at hardCap stays on it.
	it("keeps a skater riding along glass whose faces lean only by float noise, even at hardCap", function()
		local NOISE = 6.5e-5
		local tilts = { NOISE, 0, -NOISE, 0 }
		local s = skater(Vector3.zero)
		local held = true
		for frame = 1, 120 do
			s.velocity = Vector3.new(movement.hardCap, 0, 0)
			s:step(input(), ground(Vector3.new(tilts[frame % 4 + 1], 0, 1).Unit), DT)
			held = held and s.mode == "Grounded"
		end
		expect(held).toBe(true)
	end)
end)
