--!strict
-- Match rules (spec §4–§5): points to win, clock, laps to open the goal, the 12-lap streak point,
-- kickoff/celebration timing and Last Chance.

local Validate = require(script.Parent.Validate)

export type MatchConfig = {
	teamSize: number,
	minPlayersToStart: number,
	pointsToWin: number,
	durationSeconds: number,
	lapsToOpenGoal: number,
	lapsForStreakPoint: number,
	pointValue: { goal: number, streak: number },
	celebrationSeconds: number,
	kickoffCountdownSeconds: number,
	clockPausesDuringKickoff: boolean,
	postMatchSeconds: number,
	lastChance: { enabled: boolean, maxDeficit: number },
}

local defaults: MatchConfig = {
	teamSize = 3,
	minPlayersToStart = 1,
	pointsToWin = 5,
	durationSeconds = 300,
	lapsToOpenGoal = 4,
	lapsForStreakPoint = 12,
	pointValue = { goal = 1, streak = 1 },
	celebrationSeconds = 3,
	kickoffCountdownSeconds = 3,
	clockPausesDuringKickoff = true,
	postMatchSeconds = 15,
	lastChance = { enabled = true, maxDeficit = 1 },
}

local positiveInteger = Validate.number({ min = 1, integer = true })
local nonNegativeSeconds = Validate.number({ min = 0 })

local fields = Validate.record({
	teamSize = Validate.number({ min = 1, max = 6, integer = true }),
	minPlayersToStart = positiveInteger,
	pointsToWin = positiveInteger,
	durationSeconds = Validate.number({ min = 1 }),
	lapsToOpenGoal = positiveInteger,
	lapsForStreakPoint = positiveInteger,
	pointValue = Validate.record({ goal = positiveInteger, streak = positiveInteger }),
	celebrationSeconds = nonNegativeSeconds,
	kickoffCountdownSeconds = nonNegativeSeconds,
	clockPausesDuringKickoff = Validate.boolean(),
	postMatchSeconds = nonNegativeSeconds,
	lastChance = Validate.record({ enabled = Validate.boolean(), maxDeficit = positiveInteger }),
})

local streakAfterGoalOpens = Validate.check(fields, function(match: MatchConfig): boolean
	return match.lapsForStreakPoint > match.lapsToOpenGoal
end, "lapsForStreakPoint must be greater than lapsToOpenGoal")

local schema = Validate.check(streakAfterGoalOpens, function(match: MatchConfig): boolean
	return match.minPlayersToStart <= 2 * match.teamSize
end, "minPlayersToStart must be <= 2 × teamSize")

return {
	defaults = defaults,
	schema = schema,
}
