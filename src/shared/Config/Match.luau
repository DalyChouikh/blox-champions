--!strict
-- Match rules (spec §4–§5): points to win, the regulation and overtime clocks, the goal's worth by laps,
-- kickoff/celebration timing and Last Chance.

local Validate = require(script.Parent.Validate)

export type MatchConfig = {
	teamSize: number,
	minPlayersToStart: number,
	pointsToWin: number,
	durationSeconds: number,
	-- How long overtime counts down before the match ends in a draw.
	overtimeSeconds: number,
	-- What a goal is worth to the team after each lap of its streak: the goal opens after the first lap, and past
	-- the list's end a goal keeps its last value (GoalJudge.worth).
	goalPointsByLap: { number },
	celebrationSeconds: number,
	kickoffCountdownSeconds: number,
	clockPausesDuringKickoff: boolean,
	postMatchSeconds: number,
	-- How long a character that died waits before it is loaded again on its team spawn.
	respawnSeconds: number,
	-- Whether a trailing team holding the ball at 0:00 plays its one last attack, at any deficit (spec §5.3).
	lastChance: { enabled: boolean },
}

local defaults: MatchConfig = {
	teamSize = 3,
	minPlayersToStart = 1,
	pointsToWin = 5,
	-- Roller Champions' 7:00 and 3:00 of overtime (Videos 3 and 4); the draw at overtime's 0:00 is the owner's
	-- (session 21, Q95, #306), which replaces golden goal without a time limit.
	durationSeconds = 420,
	overtimeSeconds = 180,
	-- Roller Champions' +1, +3 and +5 after 1, 2 and 3 laps of 4 markers each (the owner, sessions 20-21, #305);
	-- they replace a goal of 1 after 4 laps and a streak point at 12.
	goalPointsByLap = { 1, 3, 5 },
	celebrationSeconds = 3,
	-- Roller Champions' 5, 4, 3, 2, 1, everyone free to skate and act (the owner, Q92, #307; was 3 s frozen).
	kickoffCountdownSeconds = 5,
	clockPausesDuringKickoff = true,
	postMatchSeconds = 15,
	respawnSeconds = 3,
	lastChance = { enabled = true },
}

local positiveInteger = Validate.number({ min = 1, integer = true })
local nonNegativeSeconds = Validate.number({ min = 0 })
-- A clock under a second would end regulation or overtime before anyone could play it.
local clockSeconds = Validate.number({ min = 1 })

local fields = Validate.record({
	teamSize = Validate.number({ min = 1, max = 6, integer = true }),
	minPlayersToStart = positiveInteger,
	pointsToWin = positiveInteger,
	durationSeconds = clockSeconds,
	overtimeSeconds = clockSeconds,
	goalPointsByLap = Validate.checkAll(Validate.list(positiveInteger), {
		{
			message = "must not be empty",
			holds = function(points: { number }): boolean
				return #points > 0
			end,
		},
		{
			message = "must rise, each lap worth more than the one before",
			holds = function(points: { number }): boolean
				for lap = 2, #points do
					if points[lap] <= points[lap - 1] then
						return false
					end
				end
				return true
			end,
		},
	}),
	celebrationSeconds = nonNegativeSeconds,
	kickoffCountdownSeconds = nonNegativeSeconds,
	clockPausesDuringKickoff = Validate.boolean(),
	postMatchSeconds = nonNegativeSeconds,
	respawnSeconds = nonNegativeSeconds,
	lastChance = Validate.record({ enabled = Validate.boolean() }),
})

local schema = Validate.check(fields, function(match: MatchConfig): boolean
	return match.minPlayersToStart <= 2 * match.teamSize
end, "minPlayersToStart must be <= 2 × teamSize")

return {
	defaults = defaults,
	schema = schema,
}
