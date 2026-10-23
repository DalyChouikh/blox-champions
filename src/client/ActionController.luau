--!strict
-- The local player's actions (spec §3.3, §8.1–8.3). Each physics step, after the skating (FrameController), it reads
-- the action keys and starts at most one action at once in its own ActionRunner: it pushes the skater, then asks the
-- server, which checks the action again. A throw or pass predicts the ball leaving. A refusal (ActionRejected) stops
-- the action, refunds its cooldown and gives a refused throw's ball back; a push already given stays, which the
-- movement guard tolerates. A throw let go while another action runs waits for it. Nothing starts while the skater is
-- frozen for a kickoff or knocked down.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionRunner = require(ReplicatedStorage.Shared.Actions.ActionRunner)
local Actions = require(ReplicatedStorage.Shared.Config.Actions)
local BallCarrier = require(script.Parent.BallCarrier)
local Config = require(ReplicatedStorage.Shared.Config)
local InputController = require(script.Parent.InputController)
local PlayerIds = require(ReplicatedStorage.Shared.Net.PlayerIds)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local SkateController = require(script.Parent.SkateController)
local SkateMath = require(ReplicatedStorage.Shared.Skate.SkateMath)
local Types = require(ReplicatedStorage.Shared.Rules.Types)
local Vectors = require(ReplicatedStorage.Shared.Util.Vectors)

type PlayerId = Types.PlayerId

-- Spelled out so the module is a Loader.LoadableModule and callers see its methods.
export type ActionController = {
	name: string,
	dependencies: { string },
	init: (self: ActionController, deps: { [string]: any }) -> (),
	start: (self: ActionController) -> (),
	runner: ActionRunner.Runner,
	-- The running action's pose in its windup or active phase, else "None": how PoseController poses the local skater.
	pose: (self: ActionController) -> Config.PoseName,
	step: (self: ActionController, dt: number) -> (),
	-- What an ActionRejected message runs (tests call it directly).
	rejected: (self: ActionController, payload: any) -> (),
	_config: Config.GameConfig,
	_input: InputController.InputController,
	_carrier: BallCarrier.BallCarrier,
	_skate: SkateController.SkateController,
	_camera: { CFrame: CFrame },
	_sendRequest: (payload: { [string]: any }) -> (),
	_localId: PlayerId,
	-- Records reused every step.
	_keys: InputController.ActionKeys,
	_context: ActionRunner.Context,
	-- Seconds the throw has been held with the ball; nil while not charging.
	_charge: number?,
}

-- The action a key starts: its own, or the running action's follow-up when that runs in its window (a dive during a
-- tackle's active phase).
local function forKey(self: ActionController, own: Config.ActionName): Config.ActionName
	local runner = self.runner
	local running: Config.ActionName? = runner.action
	if running == own then
		local followUp = self._config.Actions[running].followUp
		if followUp ~= nil and runner.phase == followUp.window then
			return followUp.action
		end
	end
	return own
end

-- At most one action a step, in this order: the tackle key (a dodge with the ball), the uppercut, the pass key (a call
-- without the ball), then a throw. The throw charges while held with the ball and goes when it is let go, or as soon
-- after as the runner allows; losing the ball drops the charge.
local function chosen(
	self: ActionController,
	keys: InputController.ActionKeys,
	hasBall: boolean,
	dt: number
): Config.ActionName?
	local throwReleased = false
	if not hasBall then
		self._charge = nil
	elseif keys.throw then
		self._charge = (self._charge or 0) + dt
	else
		throwReleased = self._charge ~= nil
	end
	if keys.tackle then
		return forKey(self, if hasBall then "Dodge" else "Tackle")
	elseif keys.uppercut then
		return forKey(self, "Uppercut")
	elseif keys.pass then
		return forKey(self, if hasBall then "Pass" else "CallPass")
	elseif throwReleased then
		return "ChargeThrow"
	end
	return nil
end

-- The push an action gives as it starts: a lunge along the facing, a dodge along the stick (to the right without one),
-- a leap straight up off a wall just ahead. In the air it is airMultiplier as strong.
local function push(self: ActionController, skater: SkateMath.Skater, action: Config.ActionConfig)
	local motion = action.motion
	if motion == nil then
		return
	end
	local change = Vector3.zero
	local launch = false
	if motion.lungeSpeed ~= nil then
		change += skater.forward * motion.lungeSpeed
	end
	if motion.sideSpeed ~= nil then
		local stick = self._skate.move
		local side = if stick.Magnitude > Vectors.EPSILON then stick else skater.forward:Cross(skater.up)
		if side.Magnitude > Vectors.EPSILON then
			change += side.Unit * motion.sideSpeed
		end
	end
	local impulse, reach = motion.wallLeapImpulse, motion.wallLeapDistance
	if impulse ~= nil and reach ~= nil and self._skate:wallAhead(reach) then
		change += Vector3.yAxis * impulse
		launch = true
	end
	if change.Magnitude <= Vectors.EPSILON then
		return
	end
	if skater.mode == "Airborne" then
		change *= self._config.Actions.airMultiplier
	end
	self._skate:push(change, launch)
end

-- A throw or a pass: the ball leaves the player's hands.
local function letsGoOfBall(action: Config.ActionConfig): boolean
	return action.effect == "Throw" or action.effect == "Pass"
end

-- What the server is told: the action, with the camera's aim for a throw or a pass and the charge for a throw. The
-- shape follows the action's effect, as Net/Schemas checks it.
local function request(
	self: ActionController,
	name: Config.ActionName,
	action: Config.ActionConfig,
	held: number?
): { [string]: any }
	local payload: { [string]: any } = { action = name }
	if letsGoOfBall(action) then
		payload.aim = self._camera.CFrame.LookVector
	end
	if action.effect == "Throw" then
		local throw = action.throw :: Config.ThrowSettings
		payload.charge = math.clamp((held or 0) / throw.chargeMaxSeconds, 0, 1)
	end
	return payload
end

local function begin(self: ActionController, skater: SkateMath.Skater, name: Config.ActionName, hasBall: boolean)
	local context = self._context
	context.hasBall = hasBall
	context.airborne = skater.mode == "Airborne"
	context.knockedDown = self._skate.knockedDown
	if self.runner:start(name, context) ~= "Started" then
		return
	end
	local held = self._charge
	if name == "ChargeThrow" then
		self._charge = nil
	end
	local action = self._config.Actions[name]
	push(self, skater, action)
	self._sendRequest(request(self, name, action, held))
	if letsGoOfBall(action) then
		self._carrier:predictRelease()
	end
end

local ActionController: ActionController = {
	name = "ActionController",
	dependencies = { "Config", "InputController", "BallCarrier", "SkateController" },
	runner = nil :: any,
	_config = nil :: any,
	_input = nil :: any,
	_carrier = nil :: any,
	_skate = nil :: any,
	_camera = nil :: any,
	_sendRequest = function(_payload: { [string]: any }) end,
	_localId = "",
	_keys = nil :: any,
	_context = nil :: any,
	_charge = nil,

	-- deps.Camera, deps.SendRequest and deps.LocalId replace the live game in tests.
	init = function(self: ActionController, deps: { [string]: any })
		local config: Config.GameConfig = deps.Config
		self._config = config
		self._input = deps.InputController
		self._carrier = deps.BallCarrier
		self._skate = deps.SkateController
		self._camera = deps.Camera or workspace.CurrentCamera
		self._sendRequest = deps.SendRequest
			or function(payload: { [string]: any })
				Remotes.get(ReplicatedStorage, Remotes.names.ActionRequest):FireServer(payload)
			end
		self._localId = deps.LocalId or PlayerIds.of(Players.LocalPlayer :: Player)
		self.runner = ActionRunner.new(config.Actions)
		self._keys = InputController.newActionKeys()
		self._context = { hasBall = false, airborne = false, knockedDown = false }
		self._charge = nil
	end,

	start = function(self: ActionController)
		Remotes.get(ReplicatedStorage, Remotes.names.ActionRejected).OnClientEvent:Connect(function(payload: any)
			self:rejected(payload)
		end)
	end,

	pose = function(self: ActionController): Config.PoseName
		local runner = self.runner
		local running: Config.ActionName? = runner.action
		if running == nil or runner.phase == "Recovery" then
			return "None"
		end
		return self._config.Actions[running].pose
	end,

	step = function(self: ActionController, dt: number)
		local skate = self._skate
		local skater = skate.skater
		local keys = self._keys
		-- Keys pressed while there is no skater to move, or during the freeze, are spent, not saved for later.
		if skater == nil or skate.frozen then
			self._input:readActions(keys)
			self.runner:reset()
			self._charge = nil
			return
		end
		self.runner:step(dt)
		self._input:readActions(keys)
		local hasBall = self._carrier.carrier == self._localId
		local name: Config.ActionName? = chosen(self, keys, hasBall, dt)
		if name ~= nil then
			begin(self, skater, name, hasBall)
		end
	end,

	rejected = function(self: ActionController, payload: any)
		local name: Config.ActionName? = Actions.nameOf(payload.action)
		if name ~= nil then
			self.runner:cancel(name, true)
			if letsGoOfBall(self._config.Actions[name]) then
				self._carrier:undoPrediction()
			end
		end
	end,
}

return ActionController
