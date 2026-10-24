--!strict
-- Allowances for network lag when the server judges what a player did (spec §10), and the thresholds of the movement
-- guard that catches a client moving faster than skating allows or found outside the arena.

local Validate = require(script.Parent.Validate)

export type NetworkConfig = {
	-- Extra catch reach, because the server sees each player slightly behind where their own screen does.
	pickupLagToleranceStuds: number,
	-- How often a client may report its pump and brake (a burst of this many, refilled per second).
	maxSkateStatesPerSecond: number,
	-- How often the movement guard samples each skater's position.
	guardSampleSeconds: number,
	-- How far above the allowed speed a skater may move in one sample before it counts as a strike.
	speedTolerance: number,
	-- Strikes in a row that return a skater to their last valid place.
	guardStrikes: number,
	-- A move this many times the allowed distance in one sample returns the skater at once.
	guardTeleportFactor: number,
	-- How far outside the arena's tube (past a wall, under the floor, over the roof) a skater's root may be before the
	-- guard puts them back on their team's spawn.
	guardOutsideMargin: number,
	-- How many action requests a client may send (a burst of this many, refilled per second).
	maxActionsPerSecond: number,
	-- Extra reach for strikes judged on the server, which sees each player slightly behind their own screen.
	hitLagToleranceStuds: number,
	-- How far network jitter may move an action's timing on the server: it may arrive this early before its cooldown
	-- or the running action ends, or this close to its follow-up window.
	actionTimingTolerance: number,
}

local defaults: NetworkConfig = {
	pickupLagToleranceStuds = 2,
	maxSkateStatesPerSecond = 20,
	guardSampleSeconds = 0.25,
	speedTolerance = 1.2,
	guardStrikes = 3,
	guardTeleportFactor = 2,
	guardOutsideMargin = 2,
	maxActionsPerSecond = 15,
	hitLagToleranceStuds = 3,
	actionTimingTolerance = 0.1,
}

local schema = Validate.record({
	pickupLagToleranceStuds = Validate.number({ min = 0 }),
	maxSkateStatesPerSecond = Validate.number({ above = 0 }),
	guardSampleSeconds = Validate.number({ above = 0 }),
	speedTolerance = Validate.number({ above = 0 }),
	guardStrikes = Validate.number({ min = 1, integer = true }),
	guardTeleportFactor = Validate.number({ above = 0 }),
	guardOutsideMargin = Validate.number({ min = 0 }),
	maxActionsPerSecond = Validate.number({ above = 0 }),
	hitLagToleranceStuds = Validate.number({ min = 0 }),
	actionTimingTolerance = Validate.number({ min = 0 }),
})

return {
	defaults = defaults,
	schema = schema,
}
