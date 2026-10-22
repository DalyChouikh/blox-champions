--!strict
-- Who catches a free ball this frame (spec §9.3): the nearest allowed player within reach of its center.

local Types = require(script.Parent.Parent.Rules.Types)

type PlayerId = Types.PlayerId

export type Candidate = { player: PlayerId, position: Vector3 }

local Pickup = {}

-- Writes entry `index` of a list refilled every frame, creating its record only the first time, so a list that has
-- grown refills without allocating.
function Pickup.setCandidate(candidates: { Candidate }, index: number, player: PlayerId, position: Vector3)
	local candidate = candidates[index]
	if candidate == nil then
		candidates[index] = { player = player, position = position }
	else
		candidate.player = player
		candidate.position = position
	end
end

-- Drops every entry past the first `count`.
function Pickup.trimCandidates(candidates: { Candidate }, count: number)
	for index = #candidates, count + 1, -1 do
		candidates[index] = nil
	end
end

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
