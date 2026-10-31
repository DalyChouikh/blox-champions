--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local Pose = require(ReplicatedStorage.Shared.Skate.Pose)

local pose = Config.defaults().Pose
-- A carry that raises the ball's arm out to the side: the default hangs it down (RC's carry, #311).
local raisedCarry = table.clone(pose)
raisedCarry.carryArmDeg = 75

-- A pose with nothing happening: standing, upright, carrying nothing.
local function still(): Pose.PoseInput
	return {
		lean = 0,
		airborne = false,
		pumping = false,
		braking = false,
		carrying = false,
		lunging = false,
		airPosing = false,
		knockdown = nil,
		down = 0,
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

	-- Roller Champions' Air Pose (#218): a superman stretch.
	it("strikes the Air Pose: tipped forward, legs stretched straight, the free arm reaching ahead", function()
		local out = {} :: Pose.Frame
		local input = still()
		input.airborne = true
		input.airPosing = true
		Pose.compute(pose, input, out)
		expect(out.root.LookVector.Y).toBeCloseTo(-math.sin(math.rad(70)), 6)
		expect(anglesOf(out, "leftHip")[1]).toBeCloseTo(0, 4)
		expect(anglesOf(out, "rightKnee")[1]).toBeCloseTo(0, 4)
		expect(anglesOf(out, "rightShoulder")[1]).toBeCloseTo(150, 4)
		-- A carrier keeps the ball's arm where the carry holds it: it does not reach ahead.
		input.carrying = true
		Pose.compute(pose, input, out)
		expect(anglesOf(out, "rightShoulder")[1]).toBeCloseTo(0, 4)
		expect(math.abs(anglesOf(out, "rightShoulder")[3])).toBeCloseTo(pose.carryArmDeg, 4)
		-- A lunge in the air (a dive) tips the body as a lunge does.
		input.lunging = true
		Pose.compute(pose, input, out)
		expect(out.root.LookVector.Y).toBeCloseTo(-math.sin(math.rad(pose.lungeDeg)), 6)
	end)

	-- Roller Champions carries the ball low in the right hand at the hip, the arm down (Video 13 at 99.0 s; the
	-- owner's trial #311, Q130).
	it("carries the ball with the right arm down", function()
		local out = {} :: Pose.Frame
		local input = still()
		input.carrying = true
		Pose.compute(pose, input, out)
		local angles = anglesOf(out, "rightShoulder")
		expect(angles[1]).toBeCloseTo(0, 4)
		expect(angles[2]).toBeCloseTo(0, 4)
		expect(angles[3]).toBeCloseTo(0, 4)
	end)

	it("raises the ball's arm by carryArmDeg when one is set", function()
		local out = {} :: Pose.Frame
		local input = still()
		input.carrying = true
		Pose.compute(raisedCarry, input, out)
		expect(math.abs(anglesOf(out, "rightShoulder")[3])).toBeCloseTo(raisedCarry.carryArmDeg, 4)
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
		Pose.compute(raisedCarry, turningRight, out)
		expect(points(out.root, Vector3.yAxis).X).toBeGreaterThan(0) -- into a right turn
		expect(points(out.rightShoulder, DOWN).X).toBeGreaterThan(0) -- the carry raises the right arm out to the side
	end)

	it("tips a lunging root forward and a knocked-down root back, knocked down first", function()
		local out = {} :: Pose.Frame
		-- A lunge replaces the pump's lean.
		local lunging = still()
		lunging.lunging = true
		lunging.pumping = true
		lunging.bodyOffset = 0.5
		Pose.compute(pose, lunging, out)
		expect(out.root.LookVector.Y).toBeCloseTo(-math.sin(math.rad(pose.lungeDeg)), 6)
		expect(out.root.Position.Y).toBe(0.5)

		local knockedDown = still()
		knockedDown.knockdown = "Hit"
		knockedDown.down = 1
		knockedDown.lunging = true
		Pose.compute(pose, knockedDown, out)
		expect(out.root.LookVector.Y).toBeCloseTo(math.sin(math.rad(pose.knockdownTiltDeg)), 6)
		-- The owner (#243): flat on the back on the floor, not floating at standing height, the legs straight: only a
		-- diver kneels.
		expect(out.root.Position.Y).toBeCloseTo(-pose.knockdownSinkStuds, 6)
		expect(anglesOf(out, "rightHip")[1]).toBeCloseTo(0, 4)
		expect(anglesOf(out, "rightKnee")[1]).toBeCloseTo(0, 4)
	end)

	-- The owner (#243): every knockdown eases down and back up instead of snapping.
	it("settles into a knockdown and back out evenly over knockdownEaseSeconds, never past either end", function()
		local quarter = pose.knockdownEaseSeconds / 4
		expect(Pose.settle(pose, 0, true, quarter)).toBeCloseTo(0.25, 6)
		expect(Pose.settle(pose, 0.9, true, quarter)).toBe(1)
		expect(Pose.settle(pose, 1, false, quarter)).toBeCloseTo(0.75, 6)
		expect(Pose.settle(pose, 0.1, false, quarter)).toBe(0)
	end)

	it("blends the pose before into the knockdown's, gently at both ends", function()
		local out = {} :: Pose.Frame
		local input = still()
		input.lunging = true
		input.knockdown = "Hit"
		local from, to = -pose.lungeDeg, pose.knockdownTiltDeg
		-- Halfway down, smoothstep(0.5) = 0.5 of the way: -35 + 120 × 0.5 = 25 back.
		input.down = 0.5
		Pose.compute(pose, input, out)
		expect(out.root.LookVector.Y).toBeCloseTo(math.sin(math.rad(from + (to - from) * 0.5)), 6)
		-- A quarter down, smoothstep(0.25) = 0.15625 of the way: -35 + 120 × 0.15625 = -16.25.
		input.down = 0.25
		Pose.compute(pose, input, out)
		expect(out.root.LookVector.Y).toBeCloseTo(math.sin(math.rad(from + (to - from) * 0.15625)), 6)
	end)

	-- The owner (#243): a diver lies face-down and forward, kneeling on the belly (RC, Video 4), not tipped back.
	it("lays a diver's knockdown face-down: tipped forward, kneeling, sunk toward the ground", function()
		local DOWN = -Vector3.yAxis
		local out = {} :: Pose.Frame
		local input = still()
		input.bodyOffset = 0.5
		input.knockdown = "Dive"
		input.down = 1
		Pose.compute(pose, input, out)
		expect(out.root.LookVector.Y).toBeCloseTo(-math.sin(math.rad(pose.diveDeg)), 6)
		expect(out.root.Position.Y).toBeCloseTo(0.5 - pose.diveSinkStuds, 6)
		expect(anglesOf(out, "leftHip")[1]).toBeCloseTo(pose.diveHipDeg, 4)
		expect(anglesOf(out, "rightHip")[1]).toBeCloseTo(pose.diveHipDeg, 4)
		expect(anglesOf(out, "leftKnee")[1]).toBeCloseTo(-pose.diveKneeDeg, 4)
		expect(anglesOf(out, "rightKnee")[1]).toBeCloseTo(-pose.diveKneeDeg, 4)
		-- The thighs come forward under the tipped body, and the shins fold back along the ground.
		expect((out.rightHip.Rotation * DOWN).Z).toBeLessThan(0)
		expect((out.rightKnee.Rotation * DOWN).Z).toBeGreaterThan(0)
		-- Halfway down: half the sink and half the bend (smoothstep(0.5) = 0.5).
		input.down = 0.5
		Pose.compute(pose, input, out)
		expect(out.root.Position.Y).toBeCloseTo(0.5 - pose.diveSinkStuds / 2, 6)
		expect(anglesOf(out, "leftHip")[1]).toBeCloseTo(pose.diveHipDeg / 2, 4)
		expect(anglesOf(out, "leftKnee")[1]).toBeCloseTo(-pose.diveKneeDeg / 2, 4)
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
