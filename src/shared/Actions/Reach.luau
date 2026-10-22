--!strict
-- Who a strike reaches (spec §8.2): the nearest candidate within the hit's range, and within its cone around the
-- attacker's facing pitched up by the hit's aim. Allocates nothing.

local Actions = require(script.Parent.Parent.Config.Actions)
local Pickup = require(script.Parent.Parent.Ball.Pickup)
local Types = require(script.Parent.Parent.Rules.Types)

-- A player and where they are: the shape pickups already use, so one list can serve both.
export type Candidate = Pickup.Candidate

local Reach = {}

-- `facing` and `up` are the attacker's unit look and up vectors, perpendicular as a CFrame's are. `extra` widens the
-- range (the server's lag tolerance). The edge of the range counts; an equal distance goes to the earlier candidate.
function Reach.nearest(
	origin: Vector3,
	facing: Vector3,
	up: Vector3,
	hit: Actions.Hit,
	extra: number,
	candidates: { Candidate }
): Types.PlayerId?
	local pitch = math.rad(hit.aimUpDeg)
	local aim = facing * math.cos(pitch) + up * math.sin(pitch)
	local coneCos = math.cos(math.rad(hit.coneDeg))
	local range = hit.range + extra
	local limit = range * range
	local best: Types.PlayerId? = nil
	for _, candidate in candidates do
		local offset = candidate.position - origin
		local squared = offset:Dot(offset)
		local closer = if best == nil then squared <= limit else squared < limit
		-- In the cone: the offset's angle to the unit aim is at most coneDeg, compared without dividing.
		if closer and offset:Dot(aim) >= coneCos * math.sqrt(squared) then
			best = candidate.player
			limit = squared
		end
	end
	return best
end

return table.freeze(Reach)
