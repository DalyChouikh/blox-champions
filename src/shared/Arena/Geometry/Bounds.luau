--!strict
-- Where the ball is in play (spec §9.3, owner decision 2026-10-22): anywhere between the walls at any height, and
-- above the infield while it flies over. It is out past the outer wall, below the floor, or once it comes down onto
-- the infield. Seen from above, the track is the ring between two capsules around the arena's long axis.

local Config = require(script.Parent.Parent.Parent.Config)

type ArenaConfig = Config.ArenaConfig

local Bounds = {}

-- Horizontal distance from the long axis: the segment from (-straightLength/2, 0) to (straightLength/2, 0) in X/Z.
local function fromAxis(arena: ArenaConfig, position: Vector3): number
	local half = arena.straightLength / 2
	local x = math.clamp(position.X, -half, half)
	return Vector2.new(position.X - x, position.Z).Magnitude
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

return Bounds
