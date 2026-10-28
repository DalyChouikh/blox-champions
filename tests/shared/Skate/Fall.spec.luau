--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Config = require(ReplicatedStorage.Shared.Config)
local Fall = require(ReplicatedStorage.Shared.Skate.Fall)
local Types = require(ReplicatedStorage.Shared.Skate.Types)

local config = Config.defaults()
local movement = config.Movement
local hard = movement.hardLanding
-- Where a root comes to rest over flat ground at height 0, and the first height a ray along its down reaches it from.
local REST = movement.hoverHeight
local REACH = movement.groundProbeLength
local NONE: Types.Ground = { hit = false, normal = Vector3.yAxis, distance = 0 }

-- The ground at height 0 under a root at `height`, facing `normal` (flat by default).
local function ground(height: number, normal: Vector3?): Types.Ground
	return { hit = true, normal = normal or Vector3.yAxis, distance = height }
end

-- A surface `degrees` from flat.
local function slope(degrees: number): Vector3
	return Vector3.new(math.sin(math.rad(degrees)), math.cos(math.rad(degrees)), 0)
end

-- Steps `fall` from height `from` to `to` in 2-stud frames with no ground in reach; none of them may land.
local function fly(fall: Fall.Fall, from: number, to: number)
	local direction = if to > from then 1 else -1
	for height = from, to, 2 * direction do
		assert(fall:step(height, NONE) == "None", "a frame in the air landed")
	end
	assert(fall:step(to, NONE) == "None", "a frame in the air landed")
end

-- Drops a new fall from `drop` studs above where the root comes to rest onto ground facing `normal`: how it lands.
-- The landing frame finds the ground 5 studs below, still 5 - hoverHeight above resting on it.
local function landing(drop: number, normal: Vector3?): Fall.Landing
	local fall = Fall.new(movement)
	fly(fall, REST + drop, REACH + 1)
	return fall:step(5, ground(5, normal))
end

describe("Fall", function()
	-- The owner (#222): a fall of 40 studs or more onto flat ground knocks the skater down.
	it("lands hard from hardLanding.drop or more onto flat ground, on the landing frame only", function()
		local fall = Fall.new(movement)
		fly(fall, REST + hard.drop + 0.5, REACH + 1)
		expect(fall:step(5, ground(5))).toBe("Hard")
		expect(fall:step(REST, ground(REST))).toBe("None")
		expect(landing(hard.drop - 0.5)).toBe("Soft")
	end)

	-- The owner chose 40 over 20 so that an uppercut never knocks its own user down.
	it("lands an uppercut with an Air Pose at its top safely", function()
		local leapImpulse = assert(config.Actions.Uppercut.motion).leapImpulse :: number
		-- (110² + 42²) / (2 × 196.2) = 35.3 studs.
		local leap = (leapImpulse ^ 2 + movement.airPoseImpulse ^ 2) / (2 * workspace.Gravity)
		expect(landing(leap)).toBe("Soft")
	end)

	-- Landing on a wall the way it slopes carries the skater on (Q6), so it is never hard; touching down posed there is
	-- still a fall (the owner, #258, RC Video 10), so it is a soft landing.
	it("lands softly on a wall or a bank steeper than wallAngle, however far the fall", function()
		-- 45° and 20°, either side of wallAngle 30.
		expect(landing(hard.drop + 10, slope(45))).toBe("Soft")
		expect(landing(hard.drop + 10, slope(20))).toBe("Hard")
		expect(landing(2, slope(45))).toBe("Soft")
		expect(landing(2, slope(20))).toBe("Soft")
		-- An upright wall too.
		expect(landing(2, Vector3.xAxis)).toBe("Soft")
	end)

	-- The owner (#222): an Air Pose breaks a fall.
	it("counts a fall from the top of the last rise, so an Air Pose's hop starts it over", function()
		local fall = Fall.new(movement)
		-- 42² / (2 × 196.2) = 4.5 studs.
		local hop = movement.airPoseImpulse ^ 2 / (2 * workspace.Gravity)
		fly(fall, REST + 60, REACH + 2)
		fly(fall, REACH + 2, REACH + 2 + hop)
		fly(fall, REACH + 2 + hop, REACH + 1)
		expect(fall:step(5, ground(5))).toBe("Soft")
	end)

	it("counts a fall from where the skater left the ground", function()
		local fall = Fall.new(movement)
		-- Down the glass from 60 studs to a ledge 8 up, the ground under them all the way, then off it.
		for height = REST + 60, REST + 8, -2 do
			expect(fall:step(height, ground(REST, slope(80)))).toBe("None")
		end
		fly(fall, REST + 7, REACH + 1)
		expect(fall:step(5, ground(5))).toBe("Soft")
	end)

	it("starts over where a placement puts the skater", function()
		local fall = Fall.new(movement)
		fly(fall, REST + 60, REST + 50)
		-- On the floor (a kickoff, a return to the spawn): no fall.
		fall:reset()
		expect(fall:step(REST, ground(REST))).toBe("None")
		-- Placed in the air, the fall counts from there.
		fall:reset()
		fly(fall, REST + hard.drop + 0.5, REACH + 1)
		expect(fall:step(5, ground(5))).toBe("Hard")
	end)

	-- The owner (#245): touching down still posing is a fall at any height; the server needs every landing.
	it("tells a soft landing from riding the ground: the first frame in reach after the air only", function()
		local fall = Fall.new(movement)
		fly(fall, REACH + 1, REACH + 1)
		expect(fall:step(REACH - 1, ground(REACH - 1))).toBe("Soft")
		for height = REACH - 2, REST, -1 do
			expect(fall:step(height, ground(height))).toBe("None")
		end
	end)
end)
