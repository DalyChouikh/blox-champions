--!strict
-- The exact shape of every message a client may send (spec §10.2, §13): anything else is dropped unread.

local Actions = require(script.Parent.Parent.Config.Actions)
local Finite = require(script.Parent.Parent.Util.Finite)
local Validate = require(script.Parent.Parent.Config.Validate)

-- A direction to throw or pass along: any finite, non-zero vector; the server makes it unit.
local aim = Validate.check(
	Validate.check(Validate.datatype("Vector3"), Finite.vector, "must be finite"),
	function(direction: Vector3): boolean
		return direction.Magnitude > 0
	end,
	"must not be zero"
)

-- One shape per action, by what it does: a throw carries its aim and charge, a pass its aim, the rest nothing. The
-- shape follows each action's effect, which modes never change.
local function actionRequest(): Validate.Validator
	local variants: { [string]: Validate.Validator } = {}
	for _, name: Actions.ActionName in Actions.names do
		local effect = Actions.defaults[name].effect
		local fields: { [string]: Validate.Validator } = { action = Validate.string() }
		if effect == "Throw" then
			fields.aim = aim
			fields.charge = Validate.number({ min = 0, max = 1 })
		elseif effect == "Pass" then
			fields.aim = aim
		end
		variants[name] = Validate.record(fields)
	end
	return Validate.tagged("action", variants)
end

return table.freeze({
	-- Whether the sender is pumping and braking, sent whenever either changes.
	SkateState = Validate.record({ pump = Validate.boolean(), brake = Validate.boolean() }),
	-- An action the sender started.
	ActionRequest = actionRequest(),
})
