--!strict
-- Who catches a free ball this frame (spec §9.3): the nearest allowed player within reach of its center.

local Types = require(script.Parent.Parent.Rules.Types)

type PlayerId = Types.PlayerId

export type Candidate = { player: PlayerId, position: Vector3 }

local Pickup = {}

-- The nearest allowed candidate within reach (the edge counts); an equal distance goes to the earlier candidate.
-- Compares squared distances, so it allocates nothing.
function Pickup.choose(
	ball: Vector3,
	candidates: { Candidate },
	reach: number,
	allowed: (PlayerId) -> boolean
): PlayerId?
	local best: PlayerId? = nil
	local limit = reach * reach
	for _, candidate in candidates do
		local offset = candidate.position - ball
		local squared = offset:Dot(offset)
		local closer = if best == nil then squared <= limit else squared < limit
		if closer and allowed(candidate.player) then
			best = candidate.player
			limit = squared
		end
	end
	return best
end

return Pickup
