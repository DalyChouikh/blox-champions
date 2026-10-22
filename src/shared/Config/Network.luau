--!strict
-- Allowances for network lag when the server judges what a player did (spec §10). Later phases add the action rate
-- limit and the movement guard's thresholds here.

local Validate = require(script.Parent.Validate)

export type NetworkConfig = {
	-- Extra catch reach, because the server sees each player slightly behind where their own screen does.
	pickupLagToleranceStuds: number,
}

local defaults: NetworkConfig = {
	pickupLagToleranceStuds = 2,
}

local schema = Validate.record({
	pickupLagToleranceStuds = Validate.number({ min = 0 }),
})

return {
	defaults = defaults,
	schema = schema,
}
