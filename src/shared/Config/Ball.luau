--!strict
-- The ball (spec §9.3): its size and physics, who can catch it and when, and when it is recovered.

local PartSize = require(script.Parent.Parent.Util.PartSize)
local Validate = require(script.Parent.Validate)

export type BallConfig = {
	radius: number,
	density: number,
	friction: number,
	elasticity: number,
	-- A player whose root is this close to the ball's center catches it (plus Network.pickupLagToleranceStuds).
	pickupRadius: number,
	-- How long a thrower must wait before catching their own throw.
	rethrowPickupDelay: number,
	-- A ball nobody has held for this long respawns at a ball spawn.
	ballIdleResetSeconds: number,
	-- How far past the outer wall, below the floor or onto the infield the ball's center may go before it is out.
	outOfBoundsMargin: number,
}

local defaults: BallConfig = {
	radius = 1.5,
	-- Roblox's Plastic density.
	density = 0.7,
	friction = 0.3,
	elasticity = 0.5,
	pickupRadius = 5,
	rethrowPickupDelay = 0.4,
	ballIdleResetSeconds = 15,
	outOfBoundsMargin = 2,
}

local nonNegative = Validate.number({ min = 0 })

-- Physics ranges are the ones Roblox clamps PhysicalProperties to, so a configured value is never silently changed.
local schema = Validate.record({
	radius = Validate.number({ above = 0, max = PartSize.MAX / 2 }),
	density = Validate.number({ min = 0.0001, max = 100 }),
	friction = Validate.number({ min = 0, max = 2 }),
	elasticity = Validate.number({ min = 0, max = 1 }),
	pickupRadius = Validate.number({ above = 0 }),
	rethrowPickupDelay = nonNegative,
	ballIdleResetSeconds = Validate.number({ above = 0 }),
	outOfBoundsMargin = nonNegative,
})

return {
	defaults = defaults,
	schema = schema,
}
