--!strict
-- Who a strike reaches (spec §8.2) or homes onto (#277): the nearest candidate within a cone's range, and within its
-- angle around the attacker's facing pitched up by the cone's aim. Allocates nothing.

local Actions = require(script.Parent.Parent.Config.Actions)
local Pickup = require(script.Parent.Parent.Ball.Pickup)
local Types = require(script.Parent.Parent.Rules.Types)

-- A player and where they are: the shape pickups already use, so one list can serve both.
export type Candidate = Pickup.Candidate

local Reach = {}

-- The unit way a cone looks: `facing` pitched up toward `up` by its aimUpDeg.
local function aimOf(facing: Vector3, up: Vector3, cone: Actions.Cone): Vector3
	local pitch = math.rad(cone.aimUpDeg)
	return facing * math.cos(pitch) + up * math.sin(pitch)
end

-- In the cone: the angle between `offset` (`length` long) and the unit aim is at most the cone's, compared without
-- dividing.
local function within(offset: Vector3, length: number, aim: Vector3, coneCos: number): boolean
	return offset:Dot(aim) >= coneCos * length
end

-- `facing` and `up` are the attacker's unit look and up vectors, perpendicular as a CFrame's are. `extra` widens the
-- range (the server's lag tolerance). The edges count; an equal distance goes to the earlier candidate.
function Reach.nearest(
	origin: Vector3,
	facing: Vector3,
	up: Vector3,
	cone: Actions.Cone,
	extra: number,
	candidates: { Candidate }
): Types.PlayerId?
	local aim = aimOf(facing, up, cone)
	local coneCos = math.cos(math.rad(cone.coneDeg))
	local range = cone.range + extra
	local limit = range * range
	local best: Types.PlayerId? = nil
	for _, candidate in candidates do
		local offset = candidate.position - origin
		local squared = offset:Dot(offset)
		local closer = if best == nil then squared <= limit else squared < limit
		if closer and within(offset, math.sqrt(squared), aim, coneCos) then
			best = candidate.player
			limit = squared
		end
	end
	return best
end

-- Whether a strike may reach, or home onto, a player of `otherTeam` (nil without a seat): an opponent on their
-- feet and not dodging. The server's hit and the client's homing (#277) share it.
function Reach.strikable(team: string?, otherTeam: string?, knockedDown: boolean, dodging: boolean): boolean
	return otherTeam ~= nil and otherTeam ~= team and not knockedDown and not dodging
end

-- Whether `offset` (from the attacker) lies within the cone's angle, whatever its range: a homing strike keeps
-- turning toward a target only while this holds (#277).
function Reach.inCone(offset: Vector3, facing: Vector3, up: Vector3, cone: Actions.Cone): boolean
	return within(offset, offset.Magnitude, aimOf(facing, up, cone), math.cos(math.rad(cone.coneDeg)))
end

return table.freeze(Reach)
