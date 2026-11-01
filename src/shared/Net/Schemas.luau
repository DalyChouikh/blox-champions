--!strict
-- The exact shape of every message a client may send (spec §10.2, §13): anything else is dropped unread.

local Actions = require(script.Parent.Parent.Config.Actions)
local Finite = require(script.Parent.Parent.Util.Finite)
local Validate = require(script.Parent.Parent.Config.Validate)

-- A point in the world: any finite vector.
local point = Validate.check(Validate.datatype("Vector3"), Finite.vector, "must be finite")

-- A direction to throw or pass along: any finite, non-zero vector; the server makes it unit.
local aim = Validate.check(point, function(direction: Vector3): boolean
	return direction.Magnitude > 0
end, "must not be zero")

-- One shape per action, by what it does: an action that lets go of the ball carries its aim, a throw also the
-- crosshair's spot it comes down on (#313), one that spends the charge (a throw, a roll) its charge too, the rest
-- nothing. The shape follows each action's effect, which modes never change.
local function actionRequest(): Validate.Validator
	local variants: { [string]: Validate.Validator } = {}
	for _, name: Actions.ActionName in Actions.names do
		local effect = Actions.defaults[name].effect
		local fields: { [string]: Validate.Validator } = { action = Validate.string() }
		if Actions.releasesBall(effect) then
			fields.aim = aim
		end
		if Actions.aimsAtSpot(effect) then
			fields.spot = point
		end
		if Actions.spendsCharge(effect) then
			fields.charge = Validate.number({ min = 0, max = 1 })
		end
		variants[name] = Validate.record(fields)
	end
	return Validate.tagged("action", variants)
end

-- What SkateState carries.
export type SkateState = { pump: boolean, brake: boolean, airPose: boolean }

return table.freeze({
	-- Whether the sender is pumping, braking and striking the Air Pose, sent whenever any of them changes.
	SkateState = Validate.record({
		pump = Validate.boolean(),
		brake = Validate.boolean(),
		airPose = Validate.boolean(),
	}),
	-- An action the sender started.
	ActionRequest = actionRequest(),
	-- The knocked-down sender moved: nothing else, as the server judges when they are up.
	GetUp = Validate.record({}),
	-- The sender asks to switch team: nothing else, as the server judges whether they may (#310).
	SwitchTeam = Validate.record({}),
})
