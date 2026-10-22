--!strict
-- One skater's body pose (spec §7.1): how far each joint turns, from the lean, the pump, the brake, the air and the
-- carried ball. Pure: it writes into a table the caller reuses, so a pose allocates only the CFrames it returns.
-- Every turn is in body axes (x right, y up, -z forward), which R15 joint frames match; PoseController turns them
-- into each joint's own frame. A positive turn about x tips the torso back and swings a hanging limb forward.

local Config = require(script.Parent.Parent.Config)

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
	-- How far the root joint lifts the body so the avatar's feet meet the ground.
	bodyOffset: number,
}

local Pose = {}

-- The lean that balances a turn: atan(speed × turnRate / gravity), capped at maxLeanDeg either way.
function Pose.leanDeg(pose: Config.PoseConfig, speed: number, turnRate: number, gravity: number): number
	return math.clamp(math.deg(math.atan(speed * turnRate / gravity)), -pose.maxLeanDeg, pose.maxLeanDeg)
end

function Pose.compute(pose: Config.PoseConfig, input: PoseInput, out: Frame)
	local pumping, airborne = input.pumping, input.airborne
	local crouch = pose.crouchDeg

	local rootPitch = if pumping then -crouch / 2 elseif input.braking then pose.brakeLeanDeg else 0
	out.root = CFrame.new(0, input.bodyOffset, 0) * CFrame.Angles(math.rad(rootPitch), 0, math.rad(-input.lean))
	out.waist = if pumping then CFrame.Angles(math.rad(-crouch / 2), 0, 0) else CFrame.identity

	-- The thighs come forward and the shins fold back, in a crouch and in the air's tuck alike.
	local hip = if pumping then crouch elseif airborne then pose.tuckDeg else 0
	local knee = if pumping then -2 * crouch elseif airborne then -pose.tuckDeg else 0
	local hipTurn = CFrame.Angles(math.rad(hip), 0, 0)
	local kneeTurn = CFrame.Angles(math.rad(knee), 0, 0)
	out.leftHip = hipTurn
	out.rightHip = hipTurn
	out.leftKnee = kneeTurn
	out.rightKnee = kneeTurn

	out.rightShoulder = if input.carrying then CFrame.Angles(0, 0, math.rad(pose.carryArmDeg)) else CFrame.identity
end

return Pose
