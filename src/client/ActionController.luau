--!strict
-- The local player's actions (spec §3.3, §8.1–8.3). Each physics step, after the skating (FrameController), it reads
-- the action keys and starts at most one action at once in its own ActionRunner: it pushes the skater, then asks the
-- server, which checks the action again. A throw or pass predicts the ball leaving. A refusal (ActionRejected) stops
-- the action, refunds its cooldown and gives a refused throw's ball back; a push already given stays, which the
-- movement guard tolerates. A throw let go while another action runs waits for it. Nothing starts while the skater is
-- frozen for a kickoff, knocked down or diving: an action with a landing (the Dive) holds the skater
-- (SkateController.diving) until the server knocks them down at their touchdown, and a knockdown stops the running
-- action, as the server stops it.

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
	-- The action `key` would start now (Config.Input.actions), or nil when none fits: what touch buttons and hints
	-- show.
	keyAction: (self: ActionController, key: Config.ActionKey) -> Config.ActionName?,
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
	-- Records reused every step: the keys, an action's start, and which action a key names (never knocked down).
	_keys: InputController.ActionKeys,
	_context: ActionRunner.Context,
	_keyContext: ActionRunner.Context,
	-- Seconds the throw has been held with the ball; nil while not charging.
	_charge: number?,
	-- The throw key was seen up while the player held the ball, so holding it now charges a throw.
	_throwReady: boolean,
}

-- The action `key` starts: the first of Config.Input.actions[key] whose requirements fit the ball and the air (a
-- tackle on the ground, a dive in the air); nil when none fits (an uppercut with the ball, a throw without).
local function actionFor(self: ActionController, key: Config.ActionKey, hasBall: boolean): Config.ActionName?
	local skater = self._skate.skater
	local context = self._keyContext
	context.hasBall = hasBall
	context.airborne = skater ~= nil and skater.mode == "Airborne"
	local actions = self._config.Actions
	for _, name in self._config.Input.actions[key] do
		if ActionRunner.allows(actions[name].requires, context) then
			return name
		end
	end
	return nil
end

local function holdsBall(self: ActionController): boolean
	return self._carrier.carrier == self._localId
end

-- At most one action a step, in this order: the tackle key, the uppercut, the pass key, then a throw, each starting
-- what `actionFor` names. The throw charges while held with the ball, from a press made while holding it (a key held
-- through the catch, for Ball Focus, throws nothing), and goes when it is let go, or as soon after as the runner
-- allows. Losing the ball, or Roblox's menu letting go of the key, drops the charge.
local function chosen(
	self: ActionController,
	keys: InputController.ActionKeys,
	hasBall: boolean,
	dt: number
): Config.ActionName?
	local throwReleased = false
	if not hasBall or self._input.paused then
		self._charge = nil
		self._throwReady = false
	elseif keys.throw then
		if self._throwReady then
			self._charge = (self._charge or 0) + dt
		end
	else
		throwReleased = self._charge ~= nil
		self._throwReady = true
	end
	if keys.tackle then
		return actionFor(self, "tackle", hasBall)
	elseif keys.uppercut then
		return actionFor(self, "uppercut", hasBall)
	elseif keys.pass then
		return actionFor(self, "pass", hasBall)
	elseif throwReleased then
		return actionFor(self, "throw", hasBall)
	end
	return nil
end

-- The push an action gives as it starts: a lunge along the facing, a dodge along the stick (to the right without one),
-- a leap straight up. In the air it is airMultiplier as strong, unless the action starts only there (the dive).
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
	if motion.leapImpulse ~= nil then
		change += Vector3.yAxis * motion.leapImpulse
		launch = true
	end
	if change.Magnitude <= Vectors.EPSILON then
		return
	end
	if skater.mode == "Airborne" and action.requires.grounded ~= "airborne" then
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
	local skate = self._skate
	local context = self._context
	context.hasBall = hasBall
	context.airborne = skater.mode == "Airborne"
	context.knockedDown = skate.knockedDown or skate.diving
	if self.runner:start(name, context) ~= "Started" then
		return
	end
	local held = self._charge
	if name == "ChargeThrow" then
		self._charge = nil
	end
	local action = self._config.Actions[name]
	if action.landing ~= nil then
		skate.diving = true
	end
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
	_keyContext = nil :: any,
	_charge = nil,
	_throwReady = false,

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
		self._keyContext = { hasBall = false, airborne = false, knockedDown = false }
		self._charge = nil
		self._throwReady = false
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

	keyAction = function(self: ActionController, key: Config.ActionKey): Config.ActionName?
		return actionFor(self, key, holdsBall(self))
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
			self._throwReady = false
			return
		end
		self.runner:step(dt)
		local running: Config.ActionName? = self.runner.action
		if skate.knockedDown and running ~= nil then
			self.runner:cancel(running, false)
		end
		self._input:readActions(keys)
		local hasBall = holdsBall(self)
		local name: Config.ActionName? = chosen(self, keys, hasBall, dt)
		if name ~= nil then
			begin(self, skater, name, hasBall)
		end
	end,

	rejected = function(self: ActionController, payload: any)
		local name: Config.ActionName? = Actions.nameOf(payload.action)
		if name ~= nil then
			self.runner:cancel(name, true)
			local action = self._config.Actions[name]
			if letsGoOfBall(action) then
				self._carrier:undoPrediction()
			end
			if action.landing ~= nil then
				self._skate.diving = false
			end
		end
	end,
}

return ActionController
