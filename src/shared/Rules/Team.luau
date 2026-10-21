--!strict
-- The two teams. `list` fixes their order wherever teams are listed (team scores, score tab groups).

export type Team = "Blue" | "Orange"

local Team = {}

local list: { Team } = { "Blue", "Orange" }
Team.list = table.freeze(list)

function Team.is(value: any): boolean
	return table.find(list, value) ~= nil
end

function Team.opponent(team: Team): Team
	if not Team.is(team) then
		error(`Team: unknown team "{tostring(team)}"`, 0)
	end
	return if team == "Blue" then "Orange" else "Blue"
end

return Team
