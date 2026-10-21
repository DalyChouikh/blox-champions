--!strict
-- Last Chance (spec §5.3): play goes on after 0:00 while the trailing team keeps the ball. A pickup by the
-- leading team ends the match; a trailing-team point that ties the score sends the match to overtime.

local Team = require(script.Parent.Team)

export type AfterPoint = "Overtime" | "Continue" | "Win"

local LastChance = {}

function LastChance.endsOnPickup(trailing: Team.Team, pickupTeam: Team.Team): boolean
	return pickupTeam ~= trailing
end

-- After the trailing team scores: tied → overtime; still behind → Last Chance goes on; ahead (a point worth
-- more than the deficit) → the trailing team wins, since time is already up.
function LastChance.afterPoint(scores: { [Team.Team]: number }, trailing: Team.Team): AfterPoint
	local trailingScore = scores[trailing]
	local leaderScore = scores[Team.opponent(trailing)]
	if trailingScore == leaderScore then
		return "Overtime"
	end
	return if trailingScore < leaderScore then "Continue" else "Win"
end

return LastChance
