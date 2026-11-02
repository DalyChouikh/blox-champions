--!strict
-- Score-tab points and the timing windows used to award assists and saves (spec §6).

local Validate = require(script.Parent.Validate)

export type ScoringConfig = {
	points: {
		goal: number,
		assist: number,
		save: number,
		lapCompleted: number,
		steal: number,
		tackleKnockdown: number,
	},
	assistWindowSeconds: number,
	saveLookaheadSeconds: number,
}

local defaults: ScoringConfig = {
	points = {
		goal = 100,
		assist = 50,
		save = 50,
		lapCompleted = 10,
		steal = 20,
		tackleKnockdown = 10,
	},
	assistWindowSeconds = 8,
	saveLookaheadSeconds = 1.5,
}

local points = Validate.number({ min = 0, integer = true })
local window = Validate.number({ min = 0.1 })

local schema = Validate.record({
	points = Validate.record({
		goal = points,
		assist = points,
		save = points,
		lapCompleted = points,
		steal = points,
		tackleKnockdown = points,
	}),
	assistWindowSeconds = window,
	saveLookaheadSeconds = window,
})

return {
	defaults = defaults,
	schema = schema,
}
