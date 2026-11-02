--!strict
-- The goal ring (spec §4.3): opens for the possessing team once its streak completes a lap, is worth more the more
-- laps the streak has, and scores when the ball passes through the ring, either way (Crossing), while open.

local Crossing = require(script.Parent.Crossing)
local Team = require(script.Parent.Team)

local GoalJudge = {}
GoalJudge.__index = GoalJudge

type Fields = {
	openFor: Team.Team?,
	_ring: Crossing.Disc,
}

export type GoalJudge = typeof(setmetatable({} :: Fields, GoalJudge))

function GoalJudge.new(ring: Crossing.Disc): GoalJudge
	return setmetatable({ openFor = nil, _ring = ring } :: Fields, GoalJudge)
end

-- What a goal is worth after `laps` laps of the streak: `pointsByLap[laps]`, its last value past its end (Roller
-- Champions' +5 stays +5), nothing before the first lap.
function GoalJudge.worth(pointsByLap: { number }, laps: number): number
	if laps < 1 then
		return 0
	end
	return pointsByLap[math.min(laps, #pointsByLap)]
end

-- Returns true when this lap just opened the goal for `team`: the streak's first.
function GoalJudge.lapCompleted(self: GoalJudge, team: Team.Team, streak: number): boolean
	if self.openFor ~= nil or streak < 1 then
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
