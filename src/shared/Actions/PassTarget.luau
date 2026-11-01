--!strict
-- Who a Magnetic Pass goes to (spec §8.2, #315, the owner: Q103, Q105, Q155): a teammate within the pass's cone around
-- the aim and its range, in the open: nothing of the arena on the line between the two skaters (no pass through the
-- middle glass, Q155; players are no obstacle, so an opponent can still step into a pass, Q129). Of those, the one who
-- called for it last, else the one nearest the aim's line (the smallest angle off it: the aim is the crosshair's line,
-- so the one nearest the crosshair on screen). Nobody there, no pass: Roller Champions greys Magnetic Pass then (Video
-- 34 at 41.6-43.2 s). One rule for the server, which judges the pass, and the client, which shows its target and greys
-- the key. Allocates nothing but the ray's result where the arena hides a teammate in the cone.

local Actions = require(script.Parent.Parent.Config.Actions)
local Reach = require(script.Parent.Reach)
local Types = require(script.Parent.Parent.Rules.Types)
local Vectors = require(script.Parent.Parent.Util.Vectors)

local PassTarget = {}

-- `calls` holds each calling teammate's call time (the server's clock; the server ends calls past their window), and
-- `blocking` the arena's surfaces a pass cannot fly through (its ride surfaces). The line to a teammate is looked along
-- only once they are in the cone and the range. A tie goes to the earlier teammate.
function PassTarget.choose(
	pass: Actions.PassSettings,
	passer: Vector3,
	aim: Vector3,
	teammates: { Reach.Candidate },
	calls: { [Types.PlayerId]: number },
	blocking: RaycastParams
): Types.PlayerId?
	local caller: Types.PlayerId? = nil
	local latest = -math.huge
	local nearest: Types.PlayerId? = nil
	local smallest = math.huge
	for _, teammate in teammates do
		local offset = teammate.position - passer
		local angle = math.deg(Vectors.angleBetween(aim, offset))
		if
			angle <= pass.coneDeg
			and offset.Magnitude <= pass.maxRange
			and workspace:Raycast(passer, offset, blocking) == nil
		then
			local at = calls[teammate.player]
			if at ~= nil and at > latest then
				caller = teammate.player
				latest = at
			end
			if angle < smallest then
				nearest = teammate.player
				smallest = angle
			end
		end
	end
	return caller or nearest
end

return table.freeze(PassTarget)
