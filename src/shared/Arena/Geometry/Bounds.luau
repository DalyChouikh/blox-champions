--!strict
-- Where the ball is in play and where a skater can be (Arena spec §4.3, decision A7): one box inside the glass. Seen
-- from above it is the track, the ring between two capsules around the arena's long axis (the inner and the outer
-- glass's faces); in height it runs from the lower floor up to the glass top. The ball outside it is out and
-- respawns, even over the glass top (R10); a skater outside it is placed back on their spawn (#181). No skater can
-- reach the glass top (Reach), so the top never decides a skater's case.

local Config = require(script.Parent.Parent.Parent.Config)

type ArenaConfig = Config.ArenaConfig

local Bounds = {}

-- Horizontal distance from the long axis: the segment from (-straightLength/2, 0) to (straightLength/2, 0) in X/Z.
local function fromAxis(arena: ArenaConfig, position: Vector3): number
	local half = arena.straightLength / 2
	local dx = position.X - math.clamp(position.X, -half, half)
	-- Plain arithmetic: this runs every frame the ball is free.
	return math.sqrt(dx * dx + position.Z * position.Z)
end

-- Inside the glass: between the two glass faces seen from above, no lower than the lower floor and no higher than the
-- glass top, each within `margin`. Across the track, u runs from the inner glass's face toward the outer glass's
-- (Profile). The floor is judged at the lower floor's height, so a skater under the upper floor is out once they are
-- under the lower one.
function Bounds.inArena(arena: ArenaConfig, position: Vector3, margin: number): boolean
	local u = fromAxis(arena, position) - (arena.endRadius - arena.trackWidth / 2)
	local y = position.Y
	return u >= -margin and u <= arena.trackWidth + margin and y >= -margin and y <= arena.barrier.top + margin
end

return Bounds
