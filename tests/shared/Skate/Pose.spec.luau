--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Config = require(ReplicatedStorage.Shared.Config)
local Pose = require(ReplicatedStorage.Shared.Skate.Pose)

local pose = Config.defaults().Pose

-- A pose with nothing happening: standing, upright, carrying nothing.
local function still(): Pose.PoseInput
	return {
		lean = 0,
		airborne = false,
		pumping = false,
		braking = false,
		carrying = false,
		bodyOffset = 0,
	}
end

-- Every joint's angles, read back from the CFrame the pose wrote.
local function anglesOf(out: Pose.Frame, role: Pose.Role): { number }
	local x, y, z = out[role]:ToEulerAnglesXYZ()
	return { math.deg(x), math.deg(y), math.deg(z) }
end

describe("Pose", function()
	it("leans into turns, up to maxLeanDeg", function()
		-- atan(speed × turnRate / gravity), 196.2 studs/s² being the default gravity.
		expect(Pose.leanDeg(pose, 30, 1, 196.2)).toBeCloseTo(8.6935, 3)
		expect(Pose.leanDeg(pose, 30, -1, 196.2)).toBeCloseTo(-8.6935, 3)
		expect(Pose.leanDeg(pose, 60, 2, 196.2)).toBe(30)
	end)

	it("lifts the body so the avatar's feet meet the ground", function()
		local out = {} :: Pose.Frame
		local input = still()
		input.bodyOffset = 0.5
		Pose.compute(pose, input, out)
		expect(out.root.Position.Y).toBe(0.5)
	end)

	it("crouches while pumping and leans back while braking", function()
		local out = {} :: Pose.Frame
		local pumping = still()
		pumping.pumping = true
		Pose.compute(pose, pumping, out)
		expect(math.abs(anglesOf(out, "rightKnee")[1])).toBeCloseTo(60, 4)
		expect(math.abs(anglesOf(out, "leftKnee")[1])).toBeCloseTo(60, 4)
		expect(math.abs(anglesOf(out, "rightHip")[1])).toBeCloseTo(30, 4)
		expect(math.abs(anglesOf(out, "waist")[1])).toBeCloseTo(15, 4)
		expect(math.abs(anglesOf(out, "root")[1])).toBeCloseTo(15, 4)

		local braking = still()
		braking.braking = true
		Pose.compute(pose, braking, out)
		expect(math.abs(anglesOf(out, "root")[1])).toBeCloseTo(15, 4)
		expect(anglesOf(out, "rightKnee")[1]).toBeCloseTo(0, 4)
	end)

	it("tucks the legs in the air", function()
		local out = {} :: Pose.Frame
		local input = still()
		input.airborne = true
		Pose.compute(pose, input, out)
		expect(math.abs(anglesOf(out, "leftHip")[1])).toBeCloseTo(60, 4)
		expect(math.abs(anglesOf(out, "rightHip")[1])).toBeCloseTo(60, 4)
		expect(math.abs(anglesOf(out, "leftKnee")[1])).toBeCloseTo(60, 4)
		expect(math.abs(anglesOf(out, "rightKnee")[1])).toBeCloseTo(60, 4)
	end)

	it("raises the right arm while carrying", function()
		local out = {} :: Pose.Frame
		local input = still()
		input.carrying = true
		Pose.compute(pose, input, out)
		expect(math.abs(anglesOf(out, "rightShoulder")[3])).toBeCloseTo(75, 4)
	end)
end)
