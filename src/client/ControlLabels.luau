--!strict
-- What each control does now (spec §11.1), named once for the touch buttons and the HUD's hints: the controls in the
-- order both show them, each one's label from Config.UI.controlLabels (nil while it would do nothing), and the keys
-- that work it. Nothing works without a skater. Jump needs the ground (SkateMath jumps only from it), Attach a
-- teammate right ahead (SkateController.attachable), and an action key the action it would start now
-- (ActionController:keyAction). The throw's control works Ball Focus while it would start no throw: without the ball.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionController = require(script.Parent.ActionController)
local Config = require(ReplicatedStorage.Shared.Config)
local SkateController = require(script.Parent.SkateController)

local ControlLabels = {}

-- Every control with a touch button and a hint, in the order both show them.
ControlLabels.CONTROLS = table.freeze({
	"jump",
	"pump",
	"brake",
	"attach",
	"tackle",
	"uppercut",
	"pass",
	"throw",
} :: { Config.TouchControl })

function ControlLabels.label(
	control: Config.TouchControl,
	config: Config.GameConfig,
	actions: ActionController.ActionController,
	skate: SkateController.SkateController
): string?
	local skater = skate.skater
	if skater == nil or not skate:hasSkater() then
		return nil
	end
	local labels = config.UI.controlLabels
	if control == "jump" then
		return if skater.mode == "Grounded" then labels.Jump else nil
	elseif control == "pump" then
		return labels.Pump
	elseif control == "brake" then
		return labels.Brake
	elseif control == "attach" then
		return if skate.attachable then labels.Attach else nil
	end
	local action = actions:keyAction(control :: Config.ActionKey)
	if action ~= nil then
		return labels[action]
	end
	return if control == "throw" then labels.BallFocus else nil
end

-- The keys that work `control` now (Config.Input): Ball Focus's for the throw's control while it would start no throw.
function ControlLabels.keys(
	control: Config.TouchControl,
	config: Config.GameConfig,
	actions: ActionController.ActionController
): { Enum.KeyCode }
	local input = config.Input
	if control == "throw" and actions:keyAction("throw") == nil then
		return input.ballFocus
	end
	return input[control]
end

return table.freeze(ControlLabels)
