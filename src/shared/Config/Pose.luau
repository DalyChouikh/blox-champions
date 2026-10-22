--!strict
-- How far each skater's body bends (spec §7.1): the lean into a turn, the crouch, the brake, the tuck in the air
-- and the arm that carries the ball. Angles are in degrees. Every pose number lives here, so tuning a pose is a config
-- change.

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
}

local defaults: PoseConfig = {
	maxLeanDeg = 30,
	leanSmoothing = 10,
	crouchDeg = 30,
	brakeLeanDeg = 15,
	tuckDeg = 60,
	carryArmDeg = 75,
	airborneProbe = 1.5,
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
})

return {
	defaults = defaults,
	schema = schema,
}
