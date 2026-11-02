--!strict
-- The ball (spec §9.3): its size and physics, who can catch it and when, and when it is recovered.

local Finite = require(script.Parent.Parent.Util.Finite)
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
	-- A loose ball resting this long on something nobody skates (any part of the arena but a ride surface: the goal's
	-- rim) respawns at a ball spawn; anywhere else it stays until someone picks it up.
	strandedSeconds: number,
	-- Slower than this (studs/s), a loose ball is at rest.
	restSpeed: number,
	-- How far past either glass, below the floor or over the top (Bounds.inArena) the ball's center may go before it is
	-- out.
	outOfBoundsMargin: number,
	-- Where a carried ball sits in its carrier's root frame: at their right side, clear of the floor and the legs.
	carryOffset: Vector3,
}

local defaults: BallConfig = {
	radius = 1.5,
	-- Roblox's Plastic density.
	density = 0.7,
	friction = 0.3,
	elasticity = 0.5,
	pickupRadius = 5,
	rethrowPickupDelay = 0.4,
	-- The owner (Q93, #308): no idle respawn; only a ball resting 5 s on something nobody skates respawns.
	strandedSeconds = 5,
	-- A ruling (#308): a sixth of a body length a second; a ball rolling or rocking faster is not at rest.
	restSpeed = 1,
	outOfBoundsMargin = 2,
	carryOffset = Vector3.new(2.5, 0, -0.5),
}

local nonNegative = Validate.number({ min = 0 })
local positive = Validate.number({ above = 0 })

-- Physics ranges are the ones Roblox clamps PhysicalProperties to, so a configured value is never silently changed.
local schema = Validate.record({
	radius = Validate.number({ above = 0, max = PartSize.MAX / 2 }),
	density = Validate.number({ min = 0.0001, max = 100 }),
	friction = Validate.number({ min = 0, max = 2 }),
	elasticity = Validate.number({ min = 0, max = 1 }),
	pickupRadius = positive,
	rethrowPickupDelay = nonNegative,
	strandedSeconds = positive,
	restSpeed = positive,
	outOfBoundsMargin = nonNegative,
	carryOffset = Validate.check(Validate.datatype("Vector3"), Finite.vector, "must be finite"),
})

return {
	defaults = defaults,
	schema = schema,
}
