--!strict
-- The two teams. `list` fixes their order wherever teams are listed (team scores, score tab groups).

export type Team = "Blue" | "Orange"

local Team = {}

local list: { Team } = { "Blue", "Orange" }
Team.list = table.freeze(list)

function Team.opponent(team: Team): Team
	return if team == "Blue" then "Orange" else "Blue"
end

return Team
