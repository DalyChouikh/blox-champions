--!strict
-- What each control does now (spec §11.1), named once for the touch buttons and the HUD's hints: the controls in the
-- order both show them, each one's label from Config.UI.controlLabels (nil while it would do nothing) and whether it is
-- greyed, and the keys that work it. Nothing works without a skater. Jump jumps on the ground and strikes the Air Pose
-- in the air, once until landing (SkateMath), Attach needs a teammate right ahead (SkateController.attachable), and an
-- action key names the action it would start now (ActionController:keyAction). While a throw charges (#312) the pump
-- does nothing, and the Dodge reads Cancel & Dodge, as RC's hints read then (Video 32 at 3.2 s). While knocked down or
-- diving (SkateController:controlsLocked) the skating's controls do nothing and the action keys start nothing but a
-- carrier's throw, as RC's hints read through a carrier's dive and slide (#314, Video 33 at 17.6-19.0 s). The throw's
-- control works Ball Focus while it would start no throw: without the ball. With the ball the pass's control reads
-- Magnetic Pass; with nobody to pass to it shows greyed and does not work, as RC's does (#315, Video 34 at 43.0 s).
-- An action key's row also tells how long its action still cools down (#354, the owner's Q186).

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

-- The controls that start actions (Config.Input.actions).
local ACTION_KEYS: { [string]: boolean } = table.freeze({ tackle = true, uppercut = true, pass = true, throw = true })

-- A control never greyed: lit whenever it shows.
local function lit(label: string?): (string?, boolean)
	return label, false
end

-- What `control` does now: its label (nil while it does nothing, and its button and hint hide), and whether it is
-- greyed: shown, but doing nothing now (Magnetic Pass with nobody to pass to, #315).
function ControlLabels.label(
	control: Config.TouchControl,
	config: Config.GameConfig,
	actions: ActionController.ActionController,
	skate: SkateController.SkateController
): (string?, boolean)
	local skater = skate.skater
	if skater == nil or not skate:hasSkater() then
		return lit(nil)
	end
	local labels = config.UI.controlLabels
	local charging = actions:chargeSeconds() ~= nil
	if SKATING[control] and skate:controlsLocked() then
		return lit(nil)
	elseif control == "jump" then
		if skater.mode == "Grounded" then
			return lit(labels.Jump)
		end
		return lit(if skater.mode == "Airborne" and skater.airPoseReady then labels.AirPose else nil)
	elseif control == "pump" then
		return lit(if charging then nil else labels.Pump)
	elseif control == "brake" then
		return lit(labels.Brake)
	elseif control == "attach" then
		return lit(if skate.attachable then labels.Attach else nil)
	end
	local action, ready = actions:keyAction(control :: Config.ActionKey)
	if action == nil then
		return lit(if control == "throw" then labels.BallFocus else nil)
	elseif charging and config.Actions[action].effect == "Dodge" then
		return lit(labels.CancelDodge)
	end
	return labels[action], not ready
end

-- The control whose keys work `control` now: Ball Focus for the throw's control while it would start no throw.
function ControlLabels.worked(control: Config.TouchControl, actions: ActionController.ActionController): Config.Control
	if control == "throw" and actions:keyAction("throw") == nil then
		return "ballFocus"
	end
	return control
end

-- The keys that work `control` now (Config.Input): those of ControlLabels.worked's control.
function ControlLabels.keys(
	control: Config.TouchControl,
	config: Config.GameConfig,
	actions: ActionController.ActionController
): { Enum.KeyCode }
	return config.Input[ControlLabels.worked(control, actions)]
end

-- How long the action `control` would start now still cools down (ActionRunner), in seconds, and that as a share
-- of its whole cooldown; 0 and 0 while it is not cooling, or the control starts no action.
function ControlLabels.cooldown(
	control: Config.TouchControl,
	config: Config.GameConfig,
	actions: ActionController.ActionController
): (number, number)
	if not ACTION_KEYS[control] then
		return 0, 0
	end
	local action: Config.ActionName? = actions:keyAction(control :: Config.ActionKey)
	if action == nil then
		return 0, 0
	end
	-- Never more than the whole cooldown, which a cooling action has above 0.
	local left = actions.runner:cooldownLeft(action)
	if left <= 0 then
		return 0, 0
	end
	return left, left / config.Actions[action].cooldown
end

return table.freeze(ControlLabels)
