--!strict
-- How a match ends (spec §5.2): a team reaching the points target, the next point in golden-goal overtime, or
-- the result at 0:00 — overtime on a tie, Last Chance for a close trailing team that has the ball, otherwise
-- the leader wins.

local Team = require(script.Parent.Team)
local Types = require(script.Parent.Types)

type Team = Team.Team
type Scores = { [Team]: number }

export type TimeUp = "Overtime" | "LastChance" | "Win"
export type LastChanceRule = { enabled: boolean, maxDeficit: number }

local MatchOutcome = {}

-- The winner after `scoringTeam` scores, or nil while the match goes on.
function MatchOutcome.afterPoint(period: Types.Period, scores: Scores, scoringTeam: Team, pointsToWin: number): Team?
	if period == "Overtime" or scores[scoringTeam] >= pointsToWin then
		return scoringTeam
	end
	return nil
end

-- What happens when regulation time runs out; the team is the trailing team for "LastChance" and the winner
-- for "Win".
function MatchOutcome.atTimeUp(scores: Scores, possessingTeam: Team?, lastChance: LastChanceRule): (TimeUp, Team?)
	local first: Team = Team.list[1]
	local second: Team = Team.opponent(first)
	if scores[first] == scores[second] then
		return "Overtime", nil
	end
	local leader: Team = if scores[first] > scores[second] then first else second
	local trailing: Team = Team.opponent(leader)
	local deficit = scores[leader] - scores[trailing]
	if lastChance.enabled and deficit <= lastChance.maxDeficit and possessingTeam == trailing then
		return "LastChance", trailing
	end
	return "Win", leader
end

return MatchOutcome
