--!strict
-- How the ball comes into play (spec §9.3, #321): Roller Champions' drop from above, at every kickoff and respawn. It
-- starts just under the glass's lip at a random spot anywhere round the loop, half the time on a line by the outer
-- wall and half by the middle glass, so nobody can wait for it at a spot they learned; until it first touches anything
-- or anyone it falls steadily while moving the lap's way along the track where it is, so round a curved end it follows
-- the curve instead of flying on into the glass (the owner, Q111-Q116, trial 2).

local Centerline = require(script.Parent.Parent.Arena.Geometry.Centerline)
local Config = require(script.Parent.Parent.Config)
local Profile = require(script.Parent.Parent.Arena.Geometry.Profile)

type ArenaConfig = Config.ArenaConfig
type BallConfig = Config.BallConfig

local DropIn = {}

-- Where a drop `distance` along the loop starts, on the outer wall's line or the middle glass's: its top a ball's
-- radius under the lip.
function DropIn.start(arena: ArenaConfig, ball: BallConfig, distance: number, outer: boolean): Vector3
	local dropIn = ball.dropIn
	local lateral = if outer then arena.trackWidth - dropIn.outerIn else dropIn.innerIn
	local position = Centerline.pose(arena, distance, lateral, Profile.lipStart(arena) - 2 * ball.radius)
	return position
end

-- A new drop's start: anywhere round the loop, on either line alike (Q112).
function DropIn.pick(arena: ArenaConfig, ball: BallConfig, random: Random): Vector3
	return DropIn.start(arena, ball, random:NextNumber(0, Centerline.length(arena)), random:NextNumber() < 0.5)
end

-- The velocity a drop holds at `position`: the lap's way along the track there at dropIn.speed, and straight down
-- at dropIn.descent. Numbers and Vector3s only, so holding it every frame allocates nothing.
function DropIn.velocity(arena: ArenaConfig, ball: BallConfig, position: Vector3): Vector3
	local dropIn = ball.dropIn
	local _, yaw = Centerline.pose(arena, Centerline.distanceOf(arena, position), arena.trackWidth / 2, 0)
	return Vector3.new(-math.sin(yaw) * dropIn.speed, -dropIn.descent, -math.cos(yaw) * dropIn.speed)
end

return DropIn
