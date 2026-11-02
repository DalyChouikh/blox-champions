--!strict
-- The local player's actions (spec §3.3, §8.1–8.3). Each physics step, after the skating (FrameController), it reads
-- the action keys and starts at most one action at once in its own ActionRunner: it pushes the skater, then asks the
-- server, which checks the action again. A throw, roll or pass predicts the ball leaving, aimed along the crosshair's
-- line (the camera's line through its point on the screen, CameraController:crosshair, #312); a throw is told where it
-- comes down, the spot where that line first meets the arena or the goal ring's centre (#313). With the ball, each step
-- names the teammate a Magnetic Pass would go to, by the server's own rule (PassTarget, #315): the pass key passes only
-- to them, and with nobody there it is greyed (keyAction) and does nothing. A refusal (ActionRejected) stops the
-- action, refunds its cooldown and gives a refused throw's or pass's ball back; a push already given stays (the
-- movement guard tolerates it), but a lunge eases back to the speed before over its recovery, and drops to it at once
-- when its action stops early (#241).
-- A throw charges while its key is held with the ball (RC's crosshair shows how far, #312), and starting any action
-- ends the charge: a throw, or Roll Ball on the uppercut key, spends it; a Dodge drops it (Cancel & Dodge); no pass
-- starts meanwhile, and the skating pumps nothing (SkateController.charging). A throw let go while another action
-- runs waits for it. The tackle key dives in the Tackle's follow-up window (#240), and with the ball in the Dodge's
-- (#314), the ball kept. A Tackle, Dive or Uppercut homes (#277): it turns the skater at once toward the nearest
-- opponent it may reach in its snap zone, else its cone, around the stick's way (else toward that way), and bends
-- toward them while they stay in the cone, until its recovery; the server still judges every hit. Nothing starts while
-- the skater is held still (SkateController.frozen), and nothing but a carrier's throw (#314, Q154) while knocked down
-- or diving: an action with a landing (the Dive) holds the skater (SkateController.diving) until the server knocks
-- them down at their touchdown, or until the server's rule for that knockdown's end holds here (#286), and a
-- knockdown stops the running action, as the server stops it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionRunner = require(ReplicatedStorage.Shared.Actions.ActionRunner)
local Actions = require(ReplicatedStorage.Shared.Config.Actions)
local Attributes = require(ReplicatedStorage.Shared.Net.Attributes)
local BallCarrier = require(script.Parent.BallCarrier)
local Config = require(ReplicatedStorage.Shared.Config)
local Crossing = require(ReplicatedStorage.Shared.Rules.Crossing)
local InputController = require(script.Parent.InputController)
local PassTarget = require(ReplicatedStorage.Shared.Actions.PassTarget)
local Pickup = require(ReplicatedStorage.Shared.Ball.Pickup)
local PlayerIds = require(ReplicatedStorage.Shared.Net.PlayerIds)
local Reach = require(ReplicatedStorage.Shared.Actions.Reach)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local SkateController = require(script.Parent.SkateController)
local SkateMath = require(ReplicatedStorage.Shared.Skate.SkateMath)
local Throw = require(ReplicatedStorage.Shared.Actions.Throw)
local Types = require(ReplicatedStorage.Shared.Rules.Types)
local Vectors = require(ReplicatedStorage.Shared.Util.Vectors)

type PlayerId = Types.PlayerId

-- What the actions read of the camera (CameraController; a fake in tests): throws, rolls and passes aim along the
-- crosshair's line, its origin and unit direction.
type AimCamera = { crosshair: (self: AimCamera) -> (Vector3, Vector3) }
-- What a throw's spot is found against: the arena's solid surfaces (RideSurfaces.solid) and the goal ring's opening
-- (ArenaParts), none until the arena is here; and what hides a pass's receiver, the arena's ride surfaces as the server
-- casts against them (RideSurfaces.params, #315 Q155).
type Surfaces = { solid: RaycastParams, params: RaycastParams }
type Goal = { parts: { goal: Crossing.Disc }? }

-- Spelled out so the module is a Loader.LoadableModule and callers see its methods.
export type ActionController = {
	name: string,
	dependencies: { string },
	init: (self: ActionController, deps: { [string]: any }) -> (),
	start: (self: ActionController) -> (),
	runner: ActionRunner.Runner,
	-- The running action's pose in its windup or active phase, else "None": how PoseController poses the local skater.
	pose: (self: ActionController) -> Config.PoseName,
	-- The action `key` names now (Config.Input.actions), or nil when none fits, and whether it would start: a pass
	-- names Magnetic Pass with the ball, greyed while nobody is there to take it (#315). What touch buttons and hints
	-- show.
	keyAction: (self: ActionController, key: Config.ActionKey) -> (Config.ActionName?, boolean),
	-- The teammate the pass key would pass to now (#315); nil while it would not pass: what the name tags mark.
	passTarget: (self: ActionController) -> PlayerId?,
	-- While a throw charges, how long its key has been held (on past a full charge); nil otherwise: what the
	-- crosshair's ring shows (#312: it closes at a full charge, then blinks) and what tells a Dodge it cancels the
	-- charge.
	chargeSeconds: (self: ActionController) -> number?,
	step: (self: ActionController, dt: number) -> (),
	-- What an ActionRejected message runs (tests call it directly).
	rejected: (self: ActionController, payload: any) -> (),
	_config: Config.GameConfig,
	_input: InputController.InputController,
	_carrier: BallCarrier.BallCarrier,
	_skate: SkateController.SkateController,
	_camera: AimCamera,
	_surfaces: Surfaces,
	_goal: Goal,
	_sendRequest: (payload: { [string]: any }) -> (),
	_localId: PlayerId,
	-- Records reused every step: the keys, and what the player is doing for an action's start and for which action a
	-- key names (contextNow).
	_keys: InputController.ActionKeys,
	_context: ActionRunner.Context,
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
	-- The action holding the skater in a dive (one with a landing), from its start.
	_landing: Config.ActionName?,
	-- The running strike's target (#277): their root (nil when it homes onto nobody), team and player.
	_target: BasePart?,
	_targetTeam: string?,
	_targetPlayer: PlayerId,
	-- The opponents a strike may reach, refilled at each press.
	_candidates: { Reach.Candidate },
	-- With the ball, refilled each step (#315): the teammates who can catch, their calls' times, and the one a pass
	-- would go to.
	_teammates: { Reach.Candidate },
	_calls: { [PlayerId]: number },
	_passTarget: PlayerId?,
}

-- What the player is doing now, in the reused context record: the ball, the air, whether the controls are locked
-- (knocked down or diving: SkateController:controlsLocked) and the charge.
local function contextNow(self: ActionController, hasBall: boolean): ActionRunner.Context
	local skate = self._skate
	local skater = skate.skater
	local context = self._context
	context.hasBall = hasBall
	context.airborne = skater ~= nil and skater.mode == "Airborne"
	context.knockedDown = skate:controlsLocked()
	context.charging = self._charge ~= nil
	return context
end

-- The action `key` names: the first of Config.Input.actions[key] that may start now (ActionRunner.available: its
-- requirements fit the ball, the air, the knockdown and the charge, and a follow-up's window is open: the tackle key
-- dives just after a tackle, or a dodge with the ball); nil when none fits (an uppercut with the ball and no charge, a
-- throw without the ball, anything but a carrier's throw while down). Then whether it would start: a pass only with a
-- teammate to go to (#315).
local function actionFor(self: ActionController, key: Config.ActionKey, hasBall: boolean): (Config.ActionName?, boolean)
	local context = contextNow(self, hasBall)
	for _, name in self._config.Input.actions[key] do
		if self.runner:available(name, context) then
			return name, self._config.Actions[name].effect ~= "Pass" or self._passTarget ~= nil
		end
	end
	return nil, false
end

-- The action `key` would start now, or nil.
local function startable(self: ActionController, key: Config.ActionKey, hasBall: boolean): Config.ActionName?
	local name: Config.ActionName?, ready = actionFor(self, key, hasBall)
	return if ready then name else nil
end

local function holdsBall(self: ActionController): boolean
	return self._carrier.carrier == self._localId
end

-- At most one action a step, in this order: the tackle key, the uppercut, the pass key, then a throw, each starting
-- what `actionFor` names. The throw charges while held with the ball, from a press made while holding it (a key held
-- through the catch, for Ball Focus, throws nothing), and goes when it is let go, or as soon after as the runner
-- allows. Losing the ball, or Roblox's menu letting go of the key, drops the charge, as starting another action does
-- (begin).
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
		return startable(self, "tackle", hasBall)
	elseif keys.uppercut then
		return startable(self, "uppercut", hasBall)
	elseif keys.pass then
		return startable(self, "pass", hasBall)
	elseif throwReleased then
		return startable(self, "throw", hasBall)
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
-- their character still in the world, its KnockedDown and running dodge, and whether they carry the ball (BallCarrier:
-- a carrier sliding after their own dive stays in reach, #314).
local function homeable(self: ActionController, root: BasePart, team: string?, player: PlayerId): boolean
	local character = root.Parent
	if character == nil then
		return false
	end
	local action = Actions.nameOf(character:GetAttribute(Attributes.Action) :: string?)
	local dodging = action ~= nil and self._config.Actions[action].effect == "Dodge"
	local knockdown: Attributes.Knockdown? = character:GetAttribute(Attributes.KnockedDown) :: Attributes.Knockdown?
	return Reach.strikable(self._skate:team(), team, knockdown, self._carrier.carrier == player, dodging)
end

-- The other skaters a strike may home onto, into the reused candidate list.
local function opponents(self: ActionController, views: { SkateController.SkaterView }): { Reach.Candidate }
	local list = self._candidates
	local count = 0
	for _, view in views do
		if homeable(self, view.root, view.team, view.player) then
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
			self._targetPlayer = view.player
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
	local striking: Config.ActionName? = self.runner:striking()
	if striking == nil or not homeable(self, target, self._targetTeam, self._targetPlayer) then
		self._target = nil
		return
	end
	-- Only a strike with a seek takes a target (aimStrike).
	local seek = self._config.Actions[striking].seek :: Config.Seek
	local offset = target.Position - root.Position
	if Reach.inCone(offset, skater.forward, skater.up, seek.bend) then
		local maxAngle = math.rad(seek.turnDegPerSecond) * dt
		skater:faceToward(offset, maxAngle)
		nudge(self, skater:homeChange(offset, maxAngle), false)
	end
end

-- A dive's hold also ends by the server's own rule (#286): once its strike is over and the skater is on the ground,
-- sliding slower than its landing's stopSpeed. The server's knockdown at that touchdown ends it too, but a dive that
-- stops at once (into a slope or a wall) is down for one server frame, which can come and go between two steps here.
local function settle(self: ActionController, skater: SkateMath.Skater)
	local skate = self._skate
	if not skate.diving then
		return
	end
	-- Set with the hold (begin).
	local landing = self._landing :: Config.ActionName
	if self.runner:striking() == landing or skater.mode ~= "Grounded" then
		return
	end
	if skater:shownSpeed() < (self._config.Actions[landing].landing :: Config.Landing).stopSpeed then
		skate.diving = false
	end
end

-- Where a throw along the crosshair's line from `origin` along `direction` (unit) comes down (#313, the owner: Q148):
-- where the line first meets the arena's solid surfaces within the throw's aimReach, or where it ends there, unless it
-- passes through the goal ring's opening on the way (Throw.spot). On a surface the ball's centre aims a radius off it
-- along its normal, so the ball itself touches the spot: aimed with its centre on the floor, a full throw at a spot 67
-- studs out first touched the floor 19 studs short of it (measured in Play).
local function spotAlong(
	self: ActionController,
	origin: Vector3,
	direction: Vector3,
	throw: Config.ThrowSettings
): Vector3
	local line = direction * throw.aimReach
	local hit = workspace:Raycast(origin, line, self._surfaces.solid)
	local finish = if hit ~= nil then hit.Position + hit.Normal * self._config.Ball.radius else origin + line
	local parts = self._goal.parts
	return Throw.spot(origin, finish, if parts ~= nil then parts.goal else nil)
end

-- The teammate a Magnetic Pass would go to now (#315), by the server's own rule (PassTarget.choose): of the others on
-- the local player's team who can catch (no KnockedDown, as the server's CharacterService marks them), the one it
-- names from the skater along the crosshair's line, callers ranked by the call's time their CallingPass holds, none the
-- arena's ride surfaces hide (Q155).
local function aimPass(self: ActionController, root: BasePart): PlayerId?
	local skate = self._skate
	local team = skate:team()
	if team == nil then
		return nil
	end
	local list, calls = self._teammates, self._calls
	table.clear(calls)
	local count = 0
	for _, view in skate:others() do
		local character = view.root.Parent
		if view.team == team and character ~= nil and character:GetAttribute(Attributes.KnockedDown) == nil then
			count += 1
			Pickup.setCandidate(list, count, view.player, view.root.Position)
			local at = character:GetAttribute(Attributes.CallingPass)
			if type(at) == "number" then
				calls[view.player] = at
			end
		end
	end
	Pickup.trimCandidates(list, count)
	local _, aim = self._camera:crosshair()
	local pass = self._config.Actions.Pass.pass :: Config.PassSettings
	return PassTarget.choose(pass, root.Position, aim, list, calls, self._surfaces.params)
end

-- What the server is told: the action, with the aim when it lets go of the ball, the crosshair's spot when it comes
-- down there and the charge when it spends it. The shape follows the action's effect, as Net/Schemas checks it.
local function request(
	self: ActionController,
	name: Config.ActionName,
	action: Config.ActionConfig,
	held: number?
): { [string]: any }
	local payload: { [string]: any } = { action = name }
	if Actions.releasesBall(action.effect) then
		local origin, direction = self._camera:crosshair()
		payload.aim = direction
		if Actions.aimsAtSpot(action.effect) then
			payload.spot = spotAlong(self, origin, direction, action.throw :: Config.ThrowSettings)
		end
	end
	if Actions.spendsCharge(action.effect) then
		-- One charge, ChargeThrow's: Roll Ball spends it too.
		payload.charge = Throw.share(self._config.Actions.ChargeThrow.throw :: Config.ThrowSettings, held or 0)
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
	if self.runner:start(name, contextNow(self, hasBall)) ~= "Started" then
		return
	end
	-- Whatever starts ends a charge (#312): a throw or a roll spends it, a Dodge drops it (Cancel & Dodge), and a throw
	-- key still held must come up before it charges again.
	local held = self._charge
	self._charge = nil
	if self._keys.throw then
		self._throwReady = false
	end
	local action = self._config.Actions[name]
	if action.landing ~= nil then
		skate.diving = true
		self._landing = name
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
	if Actions.releasesBall(action.effect) then
		self._carrier:predictRelease()
	end
end

local ActionController: ActionController = {
	name = "ActionController",
	dependencies = {
		"Config",
		"InputController",
		"BallCarrier",
		"SkateController",
		"CameraController",
		"RideSurfaces",
		"ArenaParts",
	},
	runner = nil :: any,
	_config = nil :: any,
	_input = nil :: any,
	_carrier = nil :: any,
	_skate = nil :: any,
	_camera = nil :: any,
	_surfaces = nil :: any,
	_goal = nil :: any,
	_sendRequest = function(_payload: { [string]: any }) end,
	_localId = "",
	_keys = nil :: any,
	_context = nil :: any,
	_charge = nil,
	_throwReady = false,
	_lunge = nil,
	_lungeBefore = 0,
	_lungePeak = nil,
	_lungeEase = 0,
	_landing = nil,
	_target = nil,
	_targetTeam = nil,
	_targetPlayer = "",
	_candidates = nil :: any,
	_teammates = nil :: any,
	_calls = nil :: any,
	_passTarget = nil,

	-- deps.Camera, deps.SendRequest and deps.LocalId replace the live game in tests.
	init = function(self: ActionController, deps: { [string]: any })
		local config: Config.GameConfig = deps.Config
		self._config = config
		self._input = deps.InputController
		self._carrier = deps.BallCarrier
		self._skate = deps.SkateController
		self._camera = deps.Camera or deps.CameraController
		self._surfaces = deps.RideSurfaces
		self._goal = deps.ArenaParts
		self._sendRequest = deps.SendRequest
			or function(payload: { [string]: any })
				Remotes.get(ReplicatedStorage, Remotes.names.ActionRequest):FireServer(payload)
			end
		self._localId = deps.LocalId or PlayerIds.of(Players.LocalPlayer :: Player)
		self.runner = ActionRunner.new(config.Actions)
		self._keys = InputController.newActionKeys()
		self._context = { hasBall = false, airborne = false, knockedDown = false, charging = false }
		self._charge = nil
		self._throwReady = false
		self._lunge = nil
		self._candidates = {}
		self._teammates = {}
		self._calls = {}
		self._passTarget = nil
	end,

	start = function(self: ActionController)
		Remotes.get(ReplicatedStorage, Remotes.names.ActionRejected).OnClientEvent:Connect(function(payload: any)
			self:rejected(payload)
		end)
	end,

	pose = function(self: ActionController): Config.PoseName
		local striking: Config.ActionName? = self.runner:striking()
		if striking == nil then
			return "None"
		end
		return self._config.Actions[striking].pose
	end,

	keyAction = function(self: ActionController, key: Config.ActionKey): (Config.ActionName?, boolean)
		return actionFor(self, key, holdsBall(self))
	end,

	passTarget = function(self: ActionController): PlayerId?
		local name: Config.ActionName? = actionFor(self, "pass", holdsBall(self))
		return if name ~= nil and self._config.Actions[name].effect == "Pass" then self._passTarget else nil
	end,

	chargeSeconds = function(self: ActionController): number?
		return self._charge
	end,

	step = function(self: ActionController, dt: number)
		local skate = self._skate
		local skater = skate.skater
		local keys = self._keys
		-- Keys pressed while there is no skater to move, or while it is held still, are spent, not saved for later.
		if skater == nil or skate.frozen then
			self._input:readActions(keys)
			self.runner:reset()
			self._charge = nil
			self._throwReady = false
			self._lunge = nil
			self._passTarget = nil
			skate.charging = false
			return
		end
		-- Bound with the skater.
		local root = skate.root :: BasePart
		self.runner:step(dt)
		local running: Config.ActionName? = self.runner.action
		if skate.knockedDown and running ~= nil then
			self.runner:cancel(running, false)
		end
		settle(self, skater)
		home(self, skater, root, dt)
		easeLunge(self, skater, dt)
		self._input:readActions(keys)
		local hasBall = holdsBall(self)
		self._passTarget = if hasBall then aimPass(self, root) else nil
		local name: Config.ActionName? = chosen(self, keys, hasBall, dt)
		if name ~= nil then
			begin(self, skater, root, name, hasBall)
		end
		-- The skating steps first: it pumps nothing from the step after a press (the owner, Q106).
		skate.charging = self._charge ~= nil
	end,

	rejected = function(self: ActionController, payload: any)
		local name: Config.ActionName? = Actions.nameOf(payload.action)
		if name ~= nil then
			self.runner:cancel(name, true)
			local action = self._config.Actions[name]
			if Actions.releasesBall(action.effect) then
				self._carrier:undoPrediction()
			end
			if action.landing ~= nil then
				self._skate.diving = false
			end
		end
	end,
}

return ActionController
