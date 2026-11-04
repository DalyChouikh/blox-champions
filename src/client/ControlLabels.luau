--!strict
-- What each control does now (spec §11.1), named once for the touch buttons and the HUD's hints: the controls in the
-- order both show them, each one's label from Config.UI.controlLabels and whether it is greyed, and the keys that work
-- it. With a skater every row shows, and one that does nothing now is greyed instead of hidden, as Roller Champions'
-- rows are (#368, the owner's Q220: in the air RC greys Uppercut, Pump and Brake, Videos 10-11; through a carrier's
-- dive every row but Charge Throw, Video 33 at 17.6-19.0 s); only Attach shows just while a teammate is right ahead
-- (SkateController.attachable, Q222). Nothing works without a skater. Jump jumps on the ground and strikes the Air Pose
-- in the air, once until landing (SkateMath); the skates push and brake only on the ground. An action key names what
-- ActionController:keyShown names: the action it would start now, else the Dive through its flight and slide, else its
-- usual one (Q222). While a throw charges (#312) the pump does nothing, and the Dodge reads Cancel & Dodge, as RC's
-- hints read then (Video 32 at 3.2 s). While knocked down or diving (SkateController:controlsLocked) the skating's
-- controls do nothing and the action keys start nothing but a carrier's throw (#314). The throw's control works Ball
-- Focus while it would start no throw: without the ball. With the ball the pass's control reads Magnetic Pass; with
-- nobody to pass to it is greyed and does not work, as RC's does (#315, Video 34 at 43.0 s). An action key's row also
-- tells how long the action it names still cools down (#354, the owner's Q186).

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

-- The controls that start actions (Config.Input.actions).
local ACTION_KEYS: { [string]: boolean } = table.freeze({ tackle = true, uppercut = true, pass = true, throw = true })

-- A control never greyed: lit whenever it shows.
local function lit(label: string?): (string?, boolean)
	return label, false
end

-- What `control` does now: its label (nil only with no skater, and for Attach with no teammate ahead: its button and
-- hint hide), and whether it is greyed: shown, but doing nothing now.
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
	local locked = skate:controlsLocked()
	-- The skates jump, push and brake only on the ground (SkateMath.stepGrounded): not in the air, nor attached,
	-- where the leader pulls them (SkateMath.follow).
	local skates = not locked and skater.mode == "Grounded"
	if control == "jump" then
		if skater.mode == "Airborne" then
			return labels.AirPose, locked or not skater.airPoseReady
		end
		return labels.Jump, not skates
	elseif control == "pump" then
		return labels.Pump, not skates or charging
	elseif control == "brake" then
		return labels.Brake, not skates
	elseif control == "attach" then
		return lit(if skate.attachable then labels.Attach else nil)
	end
	local action, ready = actions:keyShown(control :: Config.ActionKey)
	if action == nil then
		return lit(if control == "throw" then labels.BallFocus else nil)
	elseif charging and config.Actions[action].effect == "Dodge" then
		return labels.CancelDodge, not ready
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

-- How long the action `control`'s row names now (ActionController:keyShown, as its label) still cools down
-- (ActionRunner), in seconds, and that as a share of its whole cooldown; 0 and 0 while it is not cooling, or the
-- control names no action.
function ControlLabels.cooldown(
	control: Config.TouchControl,
	config: Config.GameConfig,
	actions: ActionController.ActionController
): (number, number)
	if not ACTION_KEYS[control] then
		return 0, 0
	end
	local action: Config.ActionName? = actions:keyShown(control :: Config.ActionKey)
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
