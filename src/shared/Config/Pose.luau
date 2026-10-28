--!strict
-- How far each skater's body bends (spec §7.1): the lean into a turn, the crouch, the brake, the tuck in the air,
-- the arm that carries the ball, the lunge, the knockdowns and the Air Pose. Angles are in degrees. Every pose number
-- lives here, so tuning a pose is a config change.

local Validate = require(script.Parent.Validate)

export type PoseConfig = {
	-- The most a skater leans into a turn.
	maxLeanDeg: number,
	-- How quickly the lean follows the turn, per second.
	leanSmoothing: number,
	-- A pump crouches the hips by this much, the waist by half, and bends the knees twice as far.
	crouchDeg: number,
	-- A brake leans the body back by this much.
	brakeLeanDeg: number,
	-- The legs tuck in the air by this much.
	tuckDeg: number,
	-- The arm that carries the ball rises by this much.
	carryArmDeg: number,
	-- How far past hoverHeight a remote skater's ground ray reaches before the skater counts as airborne.
	airborneProbe: number,
	-- A tackle or dive tips the body forward by this much.
	lungeDeg: number,
	-- A skater knocked down by a strike or a hard landing tips back by this much and sinks knockdownSinkStuds toward
	-- the ground: flat on the back (the owner, #243; RC's tackled skaters lie flat sliding).
	knockdownTiltDeg: number,
	knockdownSinkStuds: number,
	-- The Air Pose (#218), Roller Champions' superman stretch: the body tips forward by this much, the legs stretch
	-- straight, and the arm not carrying the ball reaches ahead by airPoseArmDeg.
	airPoseDeg: number,
	airPoseArmDeg: number,
	-- Every knockdown eases into its pose, and back upright once over, over this many seconds (#243): the owner wants
	-- a knocked-down skater's weight, never a snap.
	knockdownEaseSeconds: number,
	-- A diver's own knockdown (#243), Roller Champions' kneeling belly slide (Video 4): the body tips forward by
	-- diveDeg, the thighs swing forward by diveHipDeg under it, the shins fold back by diveKneeDeg, and the body sinks
	-- diveSinkStuds toward the ground. Both sinks fit the owner's R15 avatar: it touches the ground with no part below
	-- it (measured by forward kinematics on its joints, #243).
	diveDeg: number,
	diveHipDeg: number,
	diveKneeDeg: number,
	diveSinkStuds: number,
}

local defaults: PoseConfig = {
	maxLeanDeg = 30,
	leanSmoothing = 10,
	crouchDeg = 30,
	brakeLeanDeg = 15,
	tuckDeg = 60,
	carryArmDeg = 75,
	airborneProbe = 1.5,
	lungeDeg = 35,
	knockdownTiltDeg = 85,
	knockdownSinkStuds = 1.3,
	airPoseDeg = 70,
	airPoseArmDeg = 150,
	knockdownEaseSeconds = 0.3,
	diveDeg = 70,
	diveHipDeg = 50,
	diveKneeDeg = 110,
	diveSinkStuds = 0.7,
}

local angle = Validate.number({ min = 0, max = 180 })

local schema = Validate.record({
	maxLeanDeg = angle,
	leanSmoothing = Validate.number({ above = 0 }),
	crouchDeg = angle,
	brakeLeanDeg = angle,
	tuckDeg = angle,
	carryArmDeg = angle,
	airborneProbe = Validate.number({ min = 0 }),
	lungeDeg = angle,
	knockdownTiltDeg = angle,
	knockdownSinkStuds = Validate.number({ min = 0 }),
	airPoseDeg = angle,
	airPoseArmDeg = angle,
	knockdownEaseSeconds = Validate.number({ above = 0 }),
	diveDeg = angle,
	diveHipDeg = angle,
	diveKneeDeg = angle,
	diveSinkStuds = Validate.number({ min = 0 }),
})

return {
	defaults = defaults,
	schema = schema,
}
