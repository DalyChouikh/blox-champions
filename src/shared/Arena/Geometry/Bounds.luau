--!strict
-- Where the ball is in play (spec §9.3, owner decision 2026-10-22): anywhere between the walls at any height, and
-- above the infield while it flies over. It is out past the outer wall, below the floor, or once it comes down onto
-- the infield. Where a skater can be (spec §10.3, owner decision 2026-10-24): inside the tube (A2). Seen from above,
-- the track is the ring between two capsules around the arena's long axis.

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

function Bounds.isOut(arena: ArenaConfig, position: Vector3, margin: number): boolean
	if position.Y < -margin then
		return true
	end
	local distance = fromAxis(arena, position)
	if distance > arena.endRadius + arena.trackWidth / 2 + margin then
		return true
	end
	return distance < arena.endRadius - arena.trackWidth / 2 and position.Y < arena.infieldWallHeight + margin
end

-- Inside the tube, between its walls, above the lower floor and under the roof, or within `margin` of them. Across
-- the track, u runs from the inner wall's face toward the outer wall's (Profile): under the line between the wall tops
-- the walls hold a skater in, and over it the roof's half circle does. The floor is judged at the lower floor's
-- height, so a skater under the upper floor is out once they are under the lower one.
function Bounds.inTube(arena: ArenaConfig, position: Vector3, margin: number): boolean
	local u = fromAxis(arena, position) - (arena.endRadius - arena.trackWidth / 2)
	local y = position.Y
	if u < -margin or u > arena.trackWidth + margin or y < -margin then
		return false
	end
	local across = math.clamp(u / arena.trackWidth, 0, 1)
	if y <= arena.infieldWallHeight + (arena.outerWallHeight - arena.infieldWallHeight) * across then
		return true
	end
	local center, radius = Profile.roofCircle(arena)
	local du, dy = u - center.X, y - center.Y
	return du * du + dy * dy <= (radius + margin) * (radius + margin)
end

return Bounds
