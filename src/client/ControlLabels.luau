--!strict
-- What each control does now (spec §11.1), named once for the touch buttons and the HUD's hints: the controls in the
-- order both show them, each one's label from Config.UI.controlLabels (nil while it would do nothing), and the keys
-- that work it. Nothing works without a skater. Jump jumps on the ground and strikes the Air Pose in the air, once
-- until landing (SkateMath), Attach needs a teammate right ahead (SkateController.attachable), and an action key the
-- action it would start now (ActionController:keyAction). While a throw charges (#312) the pump does nothing, and the
-- Dodge reads Cancel & Dodge, as RC's hints read then (Video 32 at 3.2 s). While knocked down or diving
-- (SkateController:controlsLocked) the skating's controls do nothing and the action keys start nothing but a carrier's
-- throw, as RC's hints read through a carrier's dive and slide (#314, Video 33 at 17.6-19.0 s). The throw's control
-- works Ball Focus while it would start no throw: without the ball.

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

-- The controls the skating takes, which do nothing while it is locked (Attach too, but a locked skater is never
-- SkateController.attachable).
local SKATING: { [string]: boolean } = table.freeze({ jump = true, pump = true, brake = true })

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
	local charging = actions:chargeSeconds() ~= nil
	if SKATING[control] and skate:controlsLocked() then
		return nil
	elseif control == "jump" then
		if skater.mode == "Grounded" then
			return labels.Jump
		end
		return if skater.mode == "Airborne" and skater.airPoseReady then labels.AirPose else nil
	elseif control == "pump" then
		return if charging then nil else labels.Pump
	elseif control == "brake" then
		return labels.Brake
	elseif control == "attach" then
		return if skate.attachable then labels.Attach else nil
	end
	local action = actions:keyAction(control :: Config.ActionKey)
	if action == nil then
		return if control == "throw" then labels.BallFocus else nil
	elseif charging and config.Actions[action].effect == "Dodge" then
		return labels.CancelDodge
	end
	return labels[action]
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
