--!strict
-- The goal ring (spec §4.3): opens for the possessing team once its streak reaches the lap target, and
-- scores when the ball passes through the ring front-to-back (along the track direction) while open.

local Crossing = require(script.Parent.Crossing)
local Team = require(script.Parent.Team)

local GoalJudge = {}
GoalJudge.__index = GoalJudge

type Fields = {
	openFor: Team.Team?,
	_ring: Crossing.Disc,
	_lapsToOpenGoal: number,
}

export type GoalJudge = typeof(setmetatable({} :: Fields, GoalJudge))

function GoalJudge.new(ring: Crossing.Disc, lapsToOpenGoal: number): GoalJudge
	return setmetatable({ openFor = nil, _ring = ring, _lapsToOpenGoal = lapsToOpenGoal } :: Fields, GoalJudge)
end

-- Returns true when this lap just opened the goal for `team`.
function GoalJudge.lapCompleted(self: GoalJudge, team: Team.Team, streak: number): boolean
	if self.openFor ~= nil or streak < self._lapsToOpenGoal then
		return false
	end
	self.openFor = team
	return true
end

-- Returns true when the goal was open.
function GoalJudge.close(self: GoalJudge): boolean
	if self.openFor == nil then
		return false
	end
	self.openFor = nil
	return true
end

function GoalJudge.scored(self: GoalJudge, from: Vector3, to: Vector3): boolean
	return self.openFor ~= nil and Crossing.throughDisc(self._ring, from, to) ~= nil
end

return GoalJudge
