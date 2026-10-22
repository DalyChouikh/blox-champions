--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
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

	-- In body axes (x right, y up, -z forward), which an R15 avatar's joint frames match: a turn writes where a part
	-- that hangs below its joint (a thigh, a shin, an arm) or stands above it (the torso) ends up pointing.
	it("bends each joint the way a body bends", function()
		local DOWN = -Vector3.yAxis
		local function points(turn: CFrame, along: Vector3): Vector3
			return turn.Rotation * along
		end
		local out = {} :: Pose.Frame
		local pumping = still()
		pumping.pumping = true
		Pose.compute(pose, pumping, out)
		expect(points(out.root, Vector3.yAxis).Z).toBeLessThan(0) -- the body leans forward
		expect(points(out.waist, Vector3.yAxis).Z).toBeLessThan(0) -- and the chest with it
		expect(points(out.leftHip, DOWN).Z).toBeLessThan(0) -- the thighs come forward
		expect(points(out.rightHip, DOWN).Z).toBeLessThan(0)
		expect(points(out.leftKnee, DOWN).Z).toBeGreaterThan(0) -- the shins fold back
		expect(points(out.rightKnee, DOWN).Z).toBeGreaterThan(0)

		local tucked = still()
		tucked.airborne = true
		Pose.compute(pose, tucked, out)
		expect(points(out.rightHip, DOWN).Z).toBeLessThan(0)
		expect(points(out.rightKnee, DOWN).Z).toBeGreaterThan(0)

		local braking = still()
		braking.braking = true
		Pose.compute(pose, braking, out)
		expect(points(out.root, Vector3.yAxis).Z).toBeGreaterThan(0) -- the body leans back

		local turningRight = still()
		turningRight.lean = 10
		turningRight.carrying = true
		Pose.compute(pose, turningRight, out)
		expect(points(out.root, Vector3.yAxis).X).toBeGreaterThan(0) -- into a right turn
		expect(points(out.rightShoulder, DOWN).X).toBeGreaterThan(0) -- the right arm rises out to the side
	end)

	it("writes the root as the lift, then the pitch, then the roll", function()
		local out = {} :: Pose.Frame
		local input = still()
		input.pumping = true
		input.lean = 12
		input.bodyOffset = 0.5
		Pose.compute(pose, input, out)
		local expected = CFrame.new(0, 0.5, 0) * CFrame.Angles(math.rad(-pose.crouchDeg / 2), 0, math.rad(-12))
		Fixtures.expectNear(out.root.Position, expected.Position, 1e-6)
		Fixtures.expectNear(out.root.XVector, expected.XVector, 1e-6)
		Fixtures.expectNear(out.root.YVector, expected.YVector, 1e-6)
		Fixtures.expectNear(out.root.ZVector, expected.ZVector, 1e-6)
	end)
end)
