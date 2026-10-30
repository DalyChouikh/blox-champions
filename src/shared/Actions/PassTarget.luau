--!strict
-- Who a pass goes to (spec §8.2): the teammate who called for it most recently, within the call window and wherever
-- they are; otherwise the best-scored teammate within the pass's cone around the aim and its range. Allocates nothing.

local Actions = require(script.Parent.Parent.Config.Actions)
local Reach = require(script.Parent.Reach)
local Types = require(script.Parent.Parent.Rules.Types)
local Vectors = require(script.Parent.Parent.Util.Vectors)

local PassTarget = {}

-- The latest caller in `teammates` whose call (a time in `calls`) is at most `callWindow` old at `now`; a tie goes to
-- the earlier teammate.
local function caller(
	callWindow: number,
	teammates: { Reach.Candidate },
	calls: { [Types.PlayerId]: number },
	now: number
): Types.PlayerId?
	local best: Types.PlayerId? = nil
	local latest = -math.huge
	for _, teammate in teammates do
		local at = calls[teammate.player]
		if at ~= nil and now - at <= callWindow and at > latest then
			best = teammate.player
			latest = at
		end
	end
	return best
end

-- Scored by angleWeight × (1 − angle / coneDeg) + distanceWeight × (1 − distance / maxRange); higher wins, and a tie
-- goes to the earlier teammate.
function PassTarget.choose(
	pass: Actions.PassSettings,
	callWindow: number,
	passer: Vector3,
	aim: Vector3,
	teammates: { Reach.Candidate },
	calls: { [Types.PlayerId]: number },
	now: number
): Types.PlayerId?
	local called = caller(callWindow, teammates, calls, now)
	if called ~= nil then
		return called
	end
	local best: Types.PlayerId? = nil
	local bestScore = -math.huge
	for _, teammate in teammates do
		local offset = teammate.position - passer
		local distance = offset.Magnitude
		local angle = math.deg(Vectors.angleBetween(aim, offset))
		if angle <= pass.coneDeg and distance <= pass.maxRange then
			local score = pass.angleWeight * (1 - angle / pass.coneDeg)
				+ pass.distanceWeight * (1 - distance / pass.maxRange)
			if score > bestScore then
				best = teammate.player
				bestScore = score
			end
		end
	end
	return best
end

return table.freeze(PassTarget)
