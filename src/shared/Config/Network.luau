--!strict
-- Allowances for network lag when the server judges what a player did (spec §10). Later phases add the action rate
-- limit and the movement guard's thresholds here.

local Validate = require(script.Parent.Validate)

export type NetworkConfig = {
	-- Extra catch reach, because the server sees each player slightly behind where their own screen does.
	pickupLagToleranceStuds: number,
	-- How often a client may report its pump and brake (a burst of this many, refilled per second).
	maxSkateStatesPerSecond: number,
}

local defaults: NetworkConfig = {
	pickupLagToleranceStuds = 2,
	maxSkateStatesPerSecond = 20,
}

local schema = Validate.record({
	pickupLagToleranceStuds = Validate.number({ min = 0 }),
	maxSkateStatesPerSecond = Validate.number({ above = 0 }),
})

return {
	defaults = defaults,
	schema = schema,
}
