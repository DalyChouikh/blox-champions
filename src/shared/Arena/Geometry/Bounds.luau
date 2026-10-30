--!strict
-- Where the ball is in play and where a skater can be (Arena spec §4.4, decision A7): one box inside the glass. Seen
-- from above it is the track, the ring between two capsules around the arena's long axis (the inner and the outer
-- glass's faces); in height it runs from the lowest floor up to the top (Profile.topHeight). The top holds the ball and
-- every skater, so only a fault puts either outside: the ball is then out and respawns (R10), and a skater is placed
-- back on their spawn (#181).

local Config = require(script.Parent.Parent.Parent.Config)
local Profile = require(script.Parent.Profile)

type ArenaConfig = Config.ArenaConfig

local Bounds = {}

-- Horizontal distance from the long axis: the segment from (-straightLength/2, 0) to (straightLength/2, 0) in X/Z.
local function fromAxis(arena: ArenaConfig, position: Vector3): number
	local half = arena.straightLength / 2
	local dx = position.X - math.clamp(position.X, -half, half)
	-- Plain arithmetic: this runs every frame the ball is free.
	return math.sqrt(dx * dx + position.Z * position.Z)
end

-- Inside the glass: between the two glass faces seen from above, no lower than the lowest floor and no higher than the
-- top, each within `margin`. Across the track, u runs from the inner glass's face toward the outer glass's
-- (Profile). The floor is judged at its lowest height (the spawn rooms', the bowls' feet), so a skater under a higher
-- part of it is out once they are under that height.
function Bounds.inArena(arena: ArenaConfig, position: Vector3, margin: number): boolean
	local u = fromAxis(arena, position) - (arena.endRadius - arena.trackWidth / 2)
	local y = position.Y
	return u >= -margin and u <= arena.trackWidth + margin and y >= -margin and y <= Profile.topHeight(arena) + margin
end

return Bounds
