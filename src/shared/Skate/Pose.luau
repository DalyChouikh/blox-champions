--!strict
-- One skater's body pose (spec §7.1): how far each joint turns, from the lean, the pump, the brake, the air, the
-- carried ball, the lunge, the knockdown and the Air Pose. A knockdown's pose eases in and back out (`settle`, #243): a
-- strike's or a fall's lays the body flat on the back, a diver's face-down, kneeling. Pure: it writes into a
-- table the caller reuses, so a pose allocates only the CFrames it returns. Every turn is in body axes (x right, y up,
-- -z forward), which R15 joint frames match; PoseController turns them into each joint's own frame. A positive turn
-- about x tips the torso back and swings a hanging limb forward.

local Config = require(script.Parent.Parent.Config)
local Types = require(script.Parent.Types)

export type Role = "root" | "waist" | "leftHip" | "rightHip" | "leftKnee" | "rightKnee" | "rightShoulder"

-- One CFrame per role: a pose always sets all of them, so a joint that is not moving gets the identity.
export type Frame = {
	root: CFrame,
	waist: CFrame,
	leftHip: CFrame,
	rightHip: CFrame,
	leftKnee: CFrame,
	rightKnee: CFrame,
	rightShoulder: CFrame,
}

export type PoseInput = {
	-- The lean into the turn, in degrees (from leanDeg).
	lean: number,
	airborne: boolean,
	pumping: boolean,
	braking: boolean,
	carrying: boolean,
	-- A tackle or dive in its windup or active phase.
	lunging: boolean,
	-- Striking the Air Pose (SkateMath.airPosing).
	airPosing: boolean,
	-- The knockdown posed (its kind), kept while the skater rises from it; and how far into its pose they are, from 0
	-- (on their feet) to 1 (down), as `settle` moves it.
	knockdown: Types.Knockdown?,
	down: number,
	-- How far the root joint lifts the body so the avatar's feet meet the ground.
	bodyOffset: number,
}

local Pose = {}

-- The lean that balances a turn: atan(speed × turnRate / gravity), capped at maxLeanDeg either way.
function Pose.leanDeg(pose: Config.PoseConfig, speed: number, turnRate: number, gravity: number): number
	return math.clamp(math.deg(math.atan(speed * turnRate / gravity)), -pose.maxLeanDeg, pose.maxLeanDeg)
end

-- How far into its knockdown pose a skater is `dt` seconds after `down`: toward 1 while knocked down and back toward
-- 0 once up, evenly over knockdownEaseSeconds either way.
function Pose.settle(pose: Config.PoseConfig, down: number, knockedDown: boolean, dt: number): number
	local step = dt / pose.knockdownEaseSeconds
	return if knockedDown then math.min(down + step, 1) else math.max(down - step, 0)
end

-- How much of a pose `fraction` of the way shows (smoothstep): it leaves one end and reaches the other gently.
local function eased(fraction: number): number
	return fraction * fraction * (3 - 2 * fraction)
end

-- How far the body tips forward (negative) or back (positive) on its feet: a lunge, then the Air Pose, then the
-- pump's crouch or the brake's lean.
local function pitchDeg(pose: Config.PoseConfig, input: PoseInput): number
	if input.lunging then
		return -pose.lungeDeg
	elseif input.airPosing then
		return -pose.airPoseDeg
	elseif input.pumping then
		return -pose.crouchDeg / 2
	elseif input.braking then
		return pose.brakeLeanDeg
	end
	return 0
end

function Pose.compute(pose: Config.PoseConfig, input: PoseInput, out: Frame)
	local pumping, airborne = input.pumping, input.airborne
	local crouch = pose.crouchDeg
	-- How much of the knockdown's pose shows over the pose on their feet: a diver lies face-down, kneeling; anyone
	-- else flat on the back. Each tips and sinks toward the ground.
	local down = eased(input.down)
	local diving = input.knockdown == "Dive"
	local kneeling = if diving then down else 0
	local lyingDeg = if diving then -pose.diveDeg else pose.knockdownTiltDeg
	local sink = if diving then pose.diveSinkStuds else pose.knockdownSinkStuds

	-- The lift, then the pitch, then the roll: CFrame.new(0, lift, 0) * CFrame.Angles(pitch, 0, roll) written out as
	-- one CFrame, so a pose allocates one per joint.
	local standingDeg = pitchDeg(pose, input)
	local pitch = math.rad(standingDeg + (lyingDeg - standingDeg) * down)
	local roll = math.rad(-input.lean)
	local lift = input.bodyOffset - sink * down
	local cp, sp, cr, sr = math.cos(pitch), math.sin(pitch), math.cos(roll), math.sin(roll)
	out.root = CFrame.new(0, lift, 0, cr, -sr, 0, cp * sr, cp * cr, -sp, sp * sr, sp * cr, cp)
	out.waist = if pumping then CFrame.Angles(math.rad(-crouch / 2), 0, 0) else CFrame.identity

	-- The thighs come forward and the shins fold back, in a crouch and in the air's tuck alike; the Air Pose stretches
	-- them straight.
	local tucked = airborne and not input.airPosing
	local hip = if pumping then crouch elseif tucked then pose.tuckDeg else 0
	local knee = if pumping then -2 * crouch elseif tucked then -pose.tuckDeg else 0
	-- A diver kneels: the thighs come forward under the tipped body and the shins fold back along the ground.
	hip += (pose.diveHipDeg - hip) * kneeling
	knee += (-pose.diveKneeDeg - knee) * kneeling
	local hipTurn = CFrame.Angles(math.rad(hip), 0, 0)
	local kneeTurn = CFrame.Angles(math.rad(knee), 0, 0)
	out.leftHip = hipTurn
	out.rightHip = hipTurn
	out.leftKnee = kneeTurn
	out.rightKnee = kneeTurn

	out.rightShoulder = if input.carrying
		then CFrame.Angles(0, 0, math.rad(pose.carryArmDeg))
		elseif input.airPosing then CFrame.Angles(math.rad(pose.airPoseArmDeg), 0, 0)
		else CFrame.identity
end

return Pose
