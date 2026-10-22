--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local SkateMath = require(ReplicatedStorage.Shared.Skate.SkateMath)
local Types = require(ReplicatedStorage.Shared.Skate.Types)

-- Expected values come from a reference model of the formulas in the Phase 5 plan's decision 6; each comment shows
-- how to check one by hand.
local movement = Config.defaults().Movement
local FLAT = Vector3.yAxis
-- A 30° surface falling toward -Z, and the way down it.
local SLOPE = Vector3.new(0, math.cos(math.rad(30)), -math.sin(math.rad(30)))
local DOWNHILL = Vector3.new(0, -0.5, -math.cos(math.rad(30)))

local function input(overrides: { [string]: any }?): Types.SkateInput
	local record: Types.SkateInput = { move = Vector3.zero, pump = false, brake = false, jump = false, draftAccel = 0 }
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

	it("coasts without input, slowed by rolling friction and air drag", function()
		local s = skater(Vector3.new(0, 0, -60))
		s:step(input(), ground(), 0.1)
		Fixtures.expectNear(s.velocity, Vector3.new(0, 0, -59.48)) -- 60 − (4 + 1.2) × 0.1
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
		Fixtures.expectNear(s.velocity, DOWNHILL * 19.3704) -- + 196.2 × sin 30° × 0.1, then friction and drag
	end)

	it("scales speeding up down between softCap and hardCap, and never exceeds hardCap", function()
		local s = skater(DOWNHILL * 115)
		s:step(input(), ground(SLOPE), 0.01)
		expect(s.velocity.Magnitude).toBeCloseTo(115.4274, 3) -- 98.1 × (140 − 115)/(140 − 90) = 49.05 studs/s²
		local fast = skater(Vector3.new(0, 0, -150))
		fast:step(input(), ground(), 0.1)
		Fixtures.expectNear(fast.velocity, Vector3.new(0, 0, -140))
	end)

	it("turns toward the stick at a rate that shrinks with speed", function()
		local function turned(speed: number): number
			local s = skater(Vector3.new(0, 0, -speed))
			s:step(input({ move = Vector3.xAxis }), ground(), 0.1)
			return math.atan2(s.velocity.X, -s.velocity.Z)
		end
		expect(turned(70)).toBeCloseTo(0.275, 4) -- lerp(4.0, 1.5, 70/140) × 0.1
		expect(turned(140)).toBeCloseTo(0.15, 4)
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
		expect(downhill.velocity.Magnitude).toBeCloseTo(25.2446, 3) -- pull × 1.6 (19.3704 without)
		local flat = skater(Vector3.new(0, 0, -30))
		flat:step(input({ pump = true }), ground(), 0.1)
		Fixtures.expectNear(flat.velocity, Vector3.new(0, 0, -30.3384)) -- + pumpFlatAccel 8
		local pumping, coasting = skater(DOWNHILL * -30), skater(DOWNHILL * -30)
		pumping:step(input({ pump = true }), ground(SLOPE), 0.1)
		coasting:step(input(), ground(SLOPE), 0.1)
		Fixtures.expectNear(pumping.velocity, coasting.velocity) -- both (0, 9.8748, 17.1037)
	end)

	it("adds the draft's pull along the way it travels", function()
		local s = skater(Vector3.new(0, 0, -30))
		s:step(input({ draftAccel = 10 }), ground(), 0.1)
		Fixtures.expectNear(s.velocity, Vector3.new(0, 0, -30.538))
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

	it("lands only when near the ground and moving toward it", function()
		local falling = skater(Vector3.new(0, -20, -30))
		falling.mode = "Airborne"
		falling:step(input(), ground(FLAT, 2.4), 0.1)
		expect(falling.mode).toBe("Grounded")
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

	it("jumps along the surface's normal, off walls too", function()
		local flat = skater(Vector3.new(0, 0, -30))
		flat:step(input({ jump = true }), ground(), 1 / 60)
		expect(flat.mode).toBe("Airborne")
		Fixtures.expectNear(flat.velocity, Vector3.new(0, 56.7111, -29.99))
		local wall = skater(Vector3.new(0, 0, -50))
		wall:step(input({ jump = true }), ground(Vector3.xAxis), 1 / 60)
		Fixtures.expectNear(wall.velocity, Vector3.new(59.98, -3.2689, -49.9833))
	end)

	it("rides a steep surface only while fast enough", function()
		local function modeOn(degrees: number, speed: number): string
			local s = skater(Vector3.new(0, 0, -speed))
			local normal = Vector3.new(math.sin(math.rad(degrees)), math.cos(math.rad(degrees)), 0)
			s:step(input(), ground(normal), 0.1)
			return s.mode
		end
		expect(modeOn(70, 30)).toBe("Airborne")
		expect(modeOn(70, 40)).toBe("Grounded")
		expect(modeOn(50, 10)).toBe("Grounded")
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

	it("stops dead for a freeze and starts again from rest", function()
		local s = skater(Vector3.new(0, 0, -60))
		s.mode = "Airborne"
		s:stop()
		expect(s.mode).toBe("Grounded")
		Fixtures.expectNear(s.velocity, Vector3.zero)
		s:step(input({ move = -Vector3.zAxis }), ground(), 0.1)
		Fixtures.expectNear(s.velocity, Vector3.new(0, 0, -2.594))
	end)
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
		for _ = 1, 10 do
			s.velocity = Vector3.new(0, 140, 0)
			s:step(input(), ground(wall), DT)
		end
		s.velocity = Vector3.new(-140, 0, 0)
		s:step(input(), ground(ceiling), DT)
		-- The corner's turn is still within the window: the skater holds for now.
		expect(s.mode).toBe("Grounded")
		local frames = 0
		while s.mode == "Grounded" and frames < 60 do
			s.velocity = Vector3.new(-140, 0, 0)
			s:step(input(), ground(ceiling), DT)
			frames += 1
		end
		expect(s.mode).toBe("Airborne")
		-- Within the window plus a frame's travel (140 × DT = 2.3 studs).
		expect(frames * 140 * DT).toBeLessThan(movement.curvatureWindow + 140 * DT + 1e-6)
	end)

	it("drops a skater too slow for the wall rule on a tight overhang that their curve would still hold", function()
		-- A quarter-pipe of radius 2 from the floor to 5° past straight up: its curve holds anyone above 6 studs/s.
		local floor, overhang = -math.pi / 2, math.rad(5)
		expect(staysOn(40, 2, floor, overhang)).toBe(true)
		expect(staysOn(30, 2, floor, overhang)).toBe(false)
	end)

	it("keeps a skater riding a vertical wall at 40 studs/s, where gravity does not pull off", function()
		local s = skater(Vector3.new(0, 40, 0))
		s:step(input(), ground(Vector3.new(0, 0, 1)), DT)
		expect(s.mode).toBe("Grounded")
	end)
end)
