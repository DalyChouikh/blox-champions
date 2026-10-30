--!strict
-- How a match ends (spec §5.2-§5.3): a team reaching the points target, the next goal in overtime, a draw when
-- overtime runs out, and regulation's 0:00: overtime when level, Last Chance for a trailing team that has the ball,
-- otherwise the leader wins. Last Chance is one attack at any deficit (the owner, Q94): the leaders' pickup or the
-- trailing team's goal ends it.

local Team = require(script.Parent.Team)
local Types = require(script.Parent.Types)

type Team = Team.Team
type Scores = { [Team]: number }

export type AfterPoint = "Continue" | "Overtime" | "Win"
export type TimeUp = "Overtime" | "LastChance" | "Win" | "Draw"

local MatchOutcome = {}

-- The team ahead, or nil while the scores are level.
local function leader(scores: Scores): Team?
	local first: Team = Team.list[1]
	local second: Team = Team.opponent(first)
	if scores[first] == scores[second] then
		return nil
	end
	return if scores[first] > scores[second] then first else second
end

-- What follows a goal by `scoringTeam`, with the winner for "Win". A goal ends Last Chance whatever the score
-- becomes: level goes to overtime, otherwise whoever now leads wins.
function MatchOutcome.afterPoint(
	period: Types.Period,
	scores: Scores,
	scoringTeam: Team,
	pointsToWin: number
): (AfterPoint, Team?)
	if period == "Overtime" or scores[scoringTeam] >= pointsToWin then
		return "Win", scoringTeam
	end
	if period == "LastChance" then
		local ahead: Team? = leader(scores)
		if ahead == nil then
			return "Overtime", nil
		end
		return "Win", ahead
	end
	return "Continue", nil
end

-- What happens when the clock reaches 0:00 in `period`; the team is the trailing team for "LastChance" and the winner
-- for "Win". Overtime's 0:00 is a draw at once, even with a team holding the ball (the owner, Q95).
function MatchOutcome.atTimeUp(
	period: Types.Period,
	scores: Scores,
	possessingTeam: Team?,
	lastChanceEnabled: boolean
): (TimeUp, Team?)
	if period == "Overtime" then
		return "Draw", nil
	end
	local ahead: Team? = leader(scores)
	if ahead == nil then
		return "Overtime", nil
	end
	local trailing: Team = Team.opponent(ahead)
	if lastChanceEnabled and possessingTeam == trailing then
		return "LastChance", trailing
	end
	return "Win", ahead
end

-- The winner when `pickupTeam` picks up the ball while `trailing` plays its Last Chance (nil outside it): the leaders
-- win the moment they take the ball; the trailing team's own pickups keep the attack going.
function MatchOutcome.afterPickup(trailing: Team?, pickupTeam: Team): Team?
	return if trailing ~= nil and pickupTeam ~= trailing then pickupTeam else nil
end

return MatchOutcome
