--!strict
-- Which team has the ball (spec §4.1). Only a pickup by the other team changes it; loose balls, missed
-- passes and deflections never do. Neutral after a kickoff reset until the first pickup.

local Team = require(script.Parent.Team)
local Types = require(script.Parent.Types)

local Possession = {}
Possession.__index = Possession

type Fields = {
	team: Team.Team?,
	-- Who picked the ball up last for `team`: anyone who picks it up either is on it or makes it theirs. They may
	-- have left or switched team since; a ball they threw still counts for `team`, its goal for them (Q119, #310).
	lastHolder: Types.PlayerId?,
}

export type Possession = typeof(setmetatable({} :: Fields, Possession))

function Possession.new(): Possession
	return setmetatable({ team = nil, lastHolder = nil } :: Fields, Possession)
end

-- Returns true when the possessing team changed.
function Possession.pickUp(self: Possession, player: Types.PlayerId, team: Team.Team): boolean
	self.lastHolder = player
	if self.team == team then
		return false
	end
	self.team = team
	return true
end

function Possession.reset(self: Possession)
	self.team = nil
	self.lastHolder = nil
end

return Possession
