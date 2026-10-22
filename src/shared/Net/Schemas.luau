--!strict
-- The exact shape of every message a client may send (spec §10.2, §13): anything else is dropped unread.

local Validate = require(script.Parent.Parent.Config.Validate)

return table.freeze({
	-- Whether the sender is pumping and braking, sent whenever either changes.
	SkateState = Validate.record({ pump = Validate.boolean(), brake = Validate.boolean() }),
})
