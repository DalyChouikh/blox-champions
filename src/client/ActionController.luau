--!strict
-- The local player's actions (spec §3.3, §8.1–8.3). Each physics step, after the skating (FrameController), it reads
-- the action keys and starts at most one action at once in its own ActionRunner: it pushes the skater, then asks the
-- server, which checks the action again. A throw or pass predicts the ball leaving. A refusal (ActionRejected) stops
-- the action, refunds its cooldown and gives a refused throw's ball back; a push already given stays (the movement
-- guard tolerates it), but a lunge eases back to the speed before over its recovery, and drops to it at once when its
-- action stops early (#241). A throw let go while another action runs waits for it. The tackle key dives in the
-- Tackle's follow-up window (#240). A Tackle, Dive or Uppercut homes (#277): it turns the skater at once toward the
-- nearest opponent it may reach in its snap zone, else its cone, around the stick's way (else toward that way), and
-- bends toward them while they stay in the cone, until its recovery; the server still judges every hit. Nothing
-- starts while the skater is frozen for a kickoff, knocked down or diving: an action with a landing (the Dive) holds
-- the skater (SkateController.diving) until the server knocks them down at their touchdown, and a knockdown stops the
-- running action, as the server stops it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionRunner = require(ReplicatedStorage.Shared.Actions.ActionRunner)
local Actions = require(ReplicatedStorage.Shared.Config.Actions)
local Attributes = require(ReplicatedStorage.Shared.Net.Attributes)
local BallCarrier = require(script.Parent.BallCarrier)
local Config = require(ReplicatedStorage.Shared.Config)
local InputController = require(script.Parent.InputController)
local Pickup = require(ReplicatedStorage.Shared.Ball.Pickup)
local PlayerIds = require(ReplicatedStorage.Shared.Net.PlayerIds)
local Reach = require(ReplicatedStorage.Shared.Actions.Reach)
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
	-- The running action whose lunge eases back (one with a lungeCap, #241), the speed shown before it, and from its
	-- recovery's start the speed shown then and the seconds since.
	_lunge: Config.ActionName?,
	_lungeBefore: number,
	_lungePeak: number?,
	_lungeEase: number,
	-- The running strike's target (#277): their root and team; nil when it homes onto nobody.
	_target: BasePart?,
	_targetTeam: string?,
	-- The opponents a strike may reach, refilled at each press.
	_candidates: { Reach.Candidate },
}

-- The action `key` starts: the first of Config.Input.actions[key] that may start now (ActionRunner.available: its
-- requirements fit the ball and the air, and a follow-up's window is open: the tackle key dives just after a tackle);
-- nil when none fits (an uppercut with the ball, a throw without).
local function actionFor(self: ActionController, key: Config.ActionKey, hasBall: boolean): Config.ActionName?
	local skater = self._skate.skater
	local context = self._keyContext
	context.hasBall = hasBall
	context.airborne = skater ~= nil and skater.mode == "Airborne"
	for _, name in self._config.Input.actions[key] do
		if self.runner:available(name, context) then
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

-- Hands the skating a push, unless it is none.
local function nudge(self: ActionController, change: Vector3, launch: boolean)
	if change.Magnitude > Vectors.EPSILON then
		self._skate:push(change, launch)
	end
end

-- The push an action gives as it starts: a lunge along the facing up to its cap, a dodge along the stick (to the
-- right without one), a leap straight up, a dive along the way (SkateMath). In the air the lunge, dodge and leap are
-- the action's own airMultiplier, else Actions.airMultiplier, as strong; a dive's speed never is.
local function push(self: ActionController, skater: SkateMath.Skater, action: Config.ActionConfig)
	local motion = action.motion
	if motion == nil then
		return
	end
	local strength = if skater.mode == "Airborne" then action.airMultiplier or self._config.Actions.airMultiplier else 1
	local change = Vector3.zero
	local launch = false
	if motion.lungeSpeed ~= nil then
		-- The schema gives every lunge its cap.
		change += skater:lungeChange(motion.lungeSpeed * strength, motion.lungeCap :: number)
	end
	if motion.sideSpeed ~= nil then
		local stick = self._skate.move
		local side = if stick.Magnitude > Vectors.EPSILON then stick else skater.forward:Cross(skater.up)
		if side.Magnitude > Vectors.EPSILON then
			change += side.Unit * (motion.sideSpeed * strength)
		end
	end
	if motion.leapImpulse ~= nil then
		change += Vector3.yAxis * (motion.leapImpulse * strength)
		launch = true
	end
	if motion.diveSpeed ~= nil then
		change += skater:diveChange(motion.diveSpeed)
	end
	nudge(self, change, launch)
end

-- A lunge eases back (#241): from its action's recovery the speed shown is held under a ceiling falling evenly from
-- what it was then to the speed before the lunge, and once the action stops (its end, a refusal, a knockdown) at the
-- speed before. A skater the lunge left no faster than before has nothing to give back. A follow-up that replaces the
-- action (the Dive) sets its own speed: `begin` lets go of the lunge.
local function easeLunge(self: ActionController, skater: SkateMath.Skater, dt: number)
	local lunging = self._lunge
	if lunging == nil then
		return
	end
	local runner = self.runner
	local ceiling = self._lungeBefore
	if runner.action ~= lunging then
		self._lunge = nil
	elseif runner.phase ~= "Recovery" then
		return
	else
		local peak = self._lungePeak or skater:shownSpeed()
		if self._lungePeak == nil then
			if peak <= ceiling then
				self._lunge = nil
				return
			end
			self._lungePeak = peak
		end
		self._lungeEase += dt
		local recovery = self._config.Actions[lunging].phases.recovery
		ceiling = peak + (ceiling - peak) * math.min(self._lungeEase / recovery, 1)
	end
	nudge(self, skater:slowChange(ceiling), false)
end

-- A homing strike's target is someone it may reach (Reach.strikable, the server's own rule) as this client sees them:
-- their character still in the world, showing no KnockedDown and no dodge running.
local function homeable(self: ActionController, root: BasePart, team: string?): boolean
	local character = root.Parent
	if character == nil then
		return false
	end
	local action = Actions.nameOf(character:GetAttribute(Attributes.Action) :: string?)
	local dodging = action ~= nil and self._config.Actions[action].effect == "Dodge"
	local knockedDown = character:GetAttribute(Attributes.KnockedDown) ~= nil
	return Reach.strikable(self._skate:team(), team, knockedDown, dodging)
end

-- The other skaters a strike may home onto, into the reused candidate list.
local function opponents(self: ActionController, views: { SkateController.SkaterView }): { Reach.Candidate }
	local list = self._candidates
	local count = 0
	for _, view in views do
		if homeable(self, view.root, view.team) then
			count += 1
			Pickup.setCandidate(list, count, view.player, view.root.Position)
		end
	end
	Pickup.trimCandidates(list, count)
	return list
end

-- A homing strike (#277) looks along the stick's way, else the facing: the nearest opponent it may reach in its snap
-- zone, else in its bend cone, becomes its target. The skater turns at once to face and move toward them, else the
-- stick's way, keeping the speed, so the strike's own push goes that way.
local function aimStrike(self: ActionController, skater: SkateMath.Skater, root: BasePart, seek: Config.Seek)
	local skate = self._skate
	local stick = skate.move
	local way = if stick.Magnitude > Vectors.EPSILON then stick.Unit else skater.forward
	local origin = root.Position
	local views = skate:others()
	local list = opponents(self, views)
	local player = Reach.nearest(origin, way, skater.up, seek.snap, 0, list)
		or Reach.nearest(origin, way, skater.up, seek.bend, 0, list)
	local toward = stick
	for _, view in views do
		if view.player == player then
			self._target = view.root
			self._targetTeam = view.team
			toward = view.root.Position - origin
			break
		end
	end
	skater:faceToward(toward, math.huge)
	nudge(self, skater:turnChange(toward, math.huge), false)
end

-- While the strike runs, until its recovery, its motion bends toward its target at most turnDegPerSecond as long as
-- they stay in its bend cone (#277). The target goes at the recovery, when the strike stops (its end, a refusal, a
-- knockdown), or once they are down, dodging or gone.
local function home(self: ActionController, skater: SkateMath.Skater, root: BasePart, dt: number)
	local target = self._target
	if target == nil then
		return
	end
	local runner = self.runner
	local running: Config.ActionName? = runner.action
	if running == nil or runner.phase == "Recovery" or not homeable(self, target, self._targetTeam) then
		self._target = nil
		return
	end
	-- Only a strike with a seek takes a target (aimStrike).
	local seek = self._config.Actions[running].seek :: Config.Seek
	local offset = target.Position - root.Position
	if Reach.inCone(offset, skater.forward, skater.up, seek.bend) then
		local maxAngle = math.rad(seek.turnDegPerSecond) * dt
		skater:faceToward(offset, maxAngle)
		nudge(self, skater:homeChange(offset, maxAngle), false)
	end
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

local function begin(
	self: ActionController,
	skater: SkateMath.Skater,
	root: BasePart,
	name: Config.ActionName,
	hasBall: boolean
)
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
	local motion = action.motion
	self._lunge = if motion ~= nil and motion.lungeCap ~= nil then name else nil
	self._lungeBefore = skater:shownSpeed()
	self._lungePeak = nil
	self._lungeEase = 0
	self._target = nil
	local seek = action.seek
	if seek ~= nil then
		aimStrike(self, skater, root, seek)
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
	_lunge = nil,
	_lungeBefore = 0,
	_lungePeak = nil,
	_lungeEase = 0,
	_target = nil,
	_targetTeam = nil,
	_candidates = nil :: any,

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
		self._lunge = nil
		self._candidates = {}
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
			self._lunge = nil
			return
		end
		-- Bound with the skater.
		local root = skate.root :: BasePart
		self.runner:step(dt)
		local running: Config.ActionName? = self.runner.action
		if skate.knockedDown and running ~= nil then
			self.runner:cancel(running, false)
		end
		home(self, skater, root, dt)
		easeLunge(self, skater, dt)
		self._input:readActions(keys)
		local hasBall = holdsBall(self)
		local name: Config.ActionName? = chosen(self, keys, hasBall, dt)
		if name ~= nil then
			begin(self, skater, root, name, hasBall)
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
