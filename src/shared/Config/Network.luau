--!strict
-- Allowances for network lag when the server judges what a player did (spec §10), and the thresholds of the movement
-- guard that catches a client moving faster than skating allows.

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
}

local defaults: NetworkConfig = {
	pickupLagToleranceStuds = 2,
	maxSkateStatesPerSecond = 20,
	guardSampleSeconds = 0.25,
	speedTolerance = 1.2,
	guardStrikes = 3,
	guardTeleportFactor = 2,
}

local schema = Validate.record({
	pickupLagToleranceStuds = Validate.number({ min = 0 }),
	maxSkateStatesPerSecond = Validate.number({ above = 0 }),
	guardSampleSeconds = Validate.number({ above = 0 }),
	speedTolerance = Validate.number({ above = 0 }),
	guardStrikes = Validate.number({ min = 1, integer = true }),
	guardTeleportFactor = Validate.number({ above = 0 }),
})

return {
	defaults = defaults,
	schema = schema,
}
