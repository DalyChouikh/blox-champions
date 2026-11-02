--!strict
-- The ball (spec §9.3): its size and physics, how it comes into play, who can catch it and when, and when it is
-- recovered.

local Finite = require(script.Parent.Parent.Util.Finite)
local PartSize = require(script.Parent.Parent.Util.PartSize)
local Validate = require(script.Parent.Validate)

-- How the ball comes into play, at every kickoff and respawn (Ball/DropIn, #321): from just under the glass's lip at a
-- random spot round the loop, on a line by the outer wall or by the middle glass, falling steadily the lap's way along
-- the track until it first touches anything or anyone.
export type DropInSettings = {
	-- How far in from the outer wall's face and from the middle glass's face the two lines run.
	outerIn: number,
	innerIn: number,
	-- Along the track while it falls (studs/s).
	speed: number,
	-- Straight down while it falls (studs/s).
	descent: number,
}

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
	-- rim) drops back in; anywhere else it stays until someone picks it up.
	strandedSeconds: number,
	-- Slower than this (studs/s), a loose ball is at rest.
	restSpeed: number,
	dropIn: DropInSettings,
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
	-- The owner (Q111-Q116, #321): Roller Champions' drop from above at a random spot by either wall; trial 2 kept:
	-- onto the outer wall's foot or the inner bank, 3.4 body lengths a second the lap's way, landing 2.0-2.3 s after
	-- it appears (RC's took ~2.5 s).
	dropIn = { outerIn = 8, innerIn = 6, speed = 20, descent = 40 },
	outOfBoundsMargin = 2,
	carryOffset = Vector3.new(2.5, 0, -0.5),
}

local nonNegative = Validate.number({ min = 0 })
local positive = Validate.number({ above = 0 })

-- Physics ranges are the ones Roblox clamps PhysicalProperties to, so a configured value is never silently changed.
local schema = Validate.checkAll(
	Validate.record({
		radius = Validate.number({ above = 0, max = PartSize.MAX / 2 }),
		density = Validate.number({ min = 0.0001, max = 100 }),
		friction = Validate.number({ min = 0, max = 2 }),
		elasticity = Validate.number({ min = 0, max = 1 }),
		pickupRadius = positive,
		rethrowPickupDelay = nonNegative,
		strandedSeconds = positive,
		restSpeed = positive,
		dropIn = Validate.record({ outerIn = positive, innerIn = positive, speed = nonNegative, descent = positive }),
		outOfBoundsMargin = nonNegative,
		carryOffset = Validate.check(Validate.datatype("Vector3"), Finite.vector, "must be finite"),
	}),
	{
		{
			message = "the drop-in must start clear of the glass (dropIn.innerIn and dropIn.outerIn >= radius)",
			holds = function(ball: BallConfig): boolean
				return ball.dropIn.innerIn >= ball.radius and ball.dropIn.outerIn >= ball.radius
			end,
		},
	}
)

return {
	defaults = defaults,
	schema = schema,
}
