--!strict
-- The server's side of actions (spec §3.3, §8.1, §13). Every request a client sends is checked again in that player's
-- own ActionRunner and applied here, or refused with ActionRejected. Throws and passes go through BallService. Strikes
-- are judged each frame against the server's positions and knock down the nearest opponent they reach; every strike
-- of a frame aims before any lands, so two opponents who reach each other at once both go down. Knockdowns, the
-- running action (until its recovery) and calls for a pass show as character attributes every client reads. A throw
-- keeps no more of the carrier's speed than skating allows, and no more charge than the ball was held for.
-- MatchService steps it first in each frame and reports its knockdowns to the rules; a kickoff resets it. Time is the
-- sum of the frames it is stepped, so a request between frames counts as the last frame's.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionRunner = require(ReplicatedStorage.Shared.Actions.ActionRunner)
local Attributes = require(ReplicatedStorage.Shared.Net.Attributes)
local BallService = require(script.Parent.BallService)
local CharacterService = require(script.Parent.CharacterService)
local Config = require(ReplicatedStorage.Shared.Config)
local MovementCheck = require(ReplicatedStorage.Shared.Skate.MovementCheck)
local NetService = require(script.Parent.NetService)
local PassTarget = require(ReplicatedStorage.Shared.Actions.PassTarget)
local Pickup = require(ReplicatedStorage.Shared.Ball.Pickup)
local Reach = require(ReplicatedStorage.Shared.Actions.Reach)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Schemas = require(ReplicatedStorage.Shared.Net.Schemas)
local Team = require(ReplicatedStorage.Shared.Rules.Team)
local TeamService = require(script.Parent.TeamService)
local Throw = require(ReplicatedStorage.Shared.Actions.Throw)
local Types = require(ReplicatedStorage.Shared.Rules.Types)
local Vectors = require(ReplicatedStorage.Shared.Util.Vectors)

type PlayerId = Types.PlayerId
type Holder = BallService.Holder

export type Knockdown = { attacker: PlayerId, victim: PlayerId }

-- One player's actions, made on first use and kept until the player is forgotten.
type Record = {
	runner: ActionRunner.Runner,
	-- The running strike already knocked someone down: each use strikes once.
	struck: boolean,
	-- Who this frame's strike reaches and for how long it knocks them down, until every strike has aimed.
	hit: PlayerId?,
	hitSeconds: number,
	-- Seconds left knocked down; 0 when on their feet.
	knockdownLeft: number,
	-- The action the character's Action attribute shows.
	shown: Config.ActionName?,
}

-- Spelled out so the module is a Loader.LoadableModule and callers see its methods.
export type ActionService = {
	name: string,
	dependencies: { string },
	init: (self: ActionService, deps: { [string]: any }) -> (),
	start: ((self: ActionService) -> ())?,
	-- What a validated ActionRequest runs (tests call it directly).
	request: (self: ActionService, player: PlayerId, payload: any) -> (),
	-- One frame: phases, strikes, knockdowns and calls. Returns this frame's knockdowns in a list it reuses.
	step: (self: ActionService, dt: number) -> { Knockdown },
	-- The kickoff: no action, knockdown or call left, on the server or on any character.
	reset: (self: ActionService) -> (),
	forget: (self: ActionService, player: PlayerId) -> (),
	-- In a dodge's active phase: no strike reaches them.
	isImmune: (self: ActionService, player: PlayerId) -> boolean,
	_config: Config.GameConfig,
	_net: NetService.NetService,
	_ball: BallService.BallService,
	_teams: TeamService.TeamService,
	_characters: CharacterService.CharacterService,
	-- The fastest a skater may move: a client-reported velocity is never trusted beyond it.
	_speedLimit: number,
	_now: number,
	_records: { [PlayerId]: Record },
	-- Players with a record, in the order they got it, so a frame's strikes resolve the same way every time.
	_order: { PlayerId },
	-- This frame's holders, in CharacterService's order and by player.
	_holderList: { Holder },
	_holderOf: { [PlayerId]: Holder },
	-- When each player last called for a pass.
	_calls: { [PlayerId]: number },
	_candidates: { Reach.Candidate },
	_context: ActionRunner.Context,
	_knockdowns: { Knockdown },
	-- Every Knockdown record ever made, reused frame after frame.
	_knockdownPool: { Knockdown },
}

-- What a started action does on the server, by its effect.
type Effect = (self: ActionService, player: PlayerId, holder: Holder, payload: any, action: Config.ActionConfig) -> ()

-- Reads this frame's seated, living characters; every lookup of a player's root goes through it.
local function refreshHolders(self: ActionService)
	local list = self._characters:holders()
	local byPlayer = self._holderOf
	table.clear(byPlayer)
	for _, holder in list do
		byPlayer[holder.player] = holder
	end
	self._holderList = list
end

local function setAttribute(self: ActionService, player: PlayerId, name: string, value: any)
	local holder = self._holderOf[player]
	local character = if holder ~= nil then holder.root.Parent else nil
	if character ~= nil then
		character:SetAttribute(name, value)
	end
end

local function recordOf(self: ActionService, player: PlayerId): Record
	local record = self._records[player]
	if record == nil then
		record = {
			runner = ActionRunner.new(self._config.Actions),
			struck = false,
			hit = nil,
			hitSeconds = 0,
			knockdownLeft = 0,
			shown = nil,
		}
		self._records[player] = record
		table.insert(self._order, player)
	end
	return record
end

-- Keeps the character's Action attribute on the running action until its recovery, as the player's own pose shows it,
-- writing it only when it changes.
local function show(self: ActionService, player: PlayerId, record: Record)
	local runner = record.runner
	local action: Config.ActionName? = if runner.phase == "Recovery" then nil else runner.action
	if action ~= record.shown then
		record.shown = action
		setAttribute(self, player, Attributes.Action, action)
	end
end

local function reject(self: ActionService, player: PlayerId, action: Config.ActionName)
	self._net:fireTo(player, Remotes.names.ActionRejected, { action = action })
end

local function knockedDown(self: ActionService, player: PlayerId): boolean
	local record = self._records[player]
	return record ~= nil and record.knockdownLeft > 0
end

-- A teammate who can catch a pass, or an opponent a strike can reach: on their feet and not dodging.
local function reachable(self: ActionService, other: Holder, team: Team.Team?, teammates: boolean): boolean
	local otherTeam: Team.Team? = self._teams:teamOf(other.player)
	if teammates then
		return otherTeam == team and other.canCatch
	end
	if otherTeam == nil or otherTeam == team then
		return false
	end
	return not knockedDown(self, other.player) and not self:isImmune(other.player)
end

-- Fills the reused candidate list with the other holders a player's action can reach (`reachable`).
local function candidates(self: ActionService, player: PlayerId, teammates: boolean): { Reach.Candidate }
	local list = self._candidates
	local team: Team.Team? = self._teams:teamOf(player)
	local count = 0
	for _, holder in self._holderList do
		if holder.player ~= player and reachable(self, holder, team, teammates) then
			count += 1
			Pickup.setCandidate(list, count, holder.player, holder.root.Position)
		end
	end
	Pickup.trimCandidates(list, count)
	return list
end

local function addKnockdown(self: ActionService, attacker: PlayerId, victim: PlayerId)
	local list = self._knockdowns
	local index = #list + 1
	local knockdown = self._knockdownPool[index]
	if knockdown == nil then
		knockdown = { attacker = attacker, victim = victim }
		self._knockdownPool[index] = knockdown
	else
		knockdown.attacker = attacker
		knockdown.victim = victim
	end
	list[index] = knockdown
end

-- Down for `seconds`: their action stops without a refund, and a carried ball drops with their momentum.
local function knockDown(self: ActionService, attacker: PlayerId, victim: PlayerId, seconds: number)
	local record = recordOf(self, victim)
	record.knockdownLeft = seconds
	local running: Config.ActionName? = record.runner.action
	if running ~= nil then
		record.runner:cancel(running, false)
	end
	show(self, victim, record)
	setAttribute(self, victim, Attributes.KnockedDown, true)
	local holder = self._holderOf[victim]
	if holder ~= nil and self._ball.state.carrier == victim then
		self._ball:drop(holder.root.AssemblyLinearVelocity)
	end
	addKnockdown(self, attacker, victim)
end

-- A strike whose active phase this frame reached, and that has not landed yet, aims at the nearest opponent it
-- reaches. It lands in `step` once every strike has aimed.
local function aim(self: ActionService, attacker: PlayerId, record: Record)
	record.hit = nil
	local action: Config.ActionName? = record.runner.lastActive
	local holder = self._holderOf[attacker]
	if action == nil or record.struck or holder == nil then
		return
	end
	local config = self._config.Actions[action]
	local hit = config.hit
	if config.effect ~= "Knockdown" or hit == nil then
		return
	end
	local frame = holder.root.CFrame
	local extra = self._config.Network.hitLagToleranceStuds
	record.hit =
		Reach.nearest(frame.Position, frame.LookVector, frame.UpVector, hit, extra, candidates(self, attacker, false))
	record.hitSeconds = hit.knockdownSeconds
end

local function noEffect() end

local effects: { Knockdown: Effect, Dodge: Effect, Throw: Effect, Pass: Effect, CallPass: Effect } = {
	-- Strikes land in `step`, during their active phase.
	Knockdown = noEffect,
	-- A dodge only makes its player immune (isImmune).
	Dodge = noEffect,
	-- The charge the client claims, up to how long the thrower has held the ball: an honest client only charges
	-- once it learns it carries, so its hold is never longer than the server's.
	Throw = function(self: ActionService, player: PlayerId, holder: Holder, payload: any, action: Config.ActionConfig)
		local throw = action.throw :: Config.ThrowSettings
		local charge = math.min(payload.charge, self._ball.state.heldSeconds / throw.chargeMaxSeconds)
		local carrier = Vectors.clampMagnitude(holder.root.AssemblyLinearVelocity, self._speedLimit)
		self._ball:throw(player, Throw.charged(throw, payload.aim, charge, carrier))
	end,
	Pass = function(self: ActionService, player: PlayerId, holder: Holder, payload: any, action: Config.ActionConfig)
		local pass = action.pass :: Config.PassSettings
		local window = self._config.Actions.callPassWindow
		local teammates = candidates(self, player, true)
		local target =
			PassTarget.choose(pass, window, holder.root.Position, payload.aim, teammates, self._calls, self._now)
		local targetHolder = if target ~= nil then self._holderOf[target] else nil
		local targetAt = if targetHolder ~= nil then targetHolder.root.Position else nil
		self._ball:pass(player, Throw.pass(pass, self._ball.part.Position, payload.aim, targetAt), target)
	end,
	CallPass = function(self: ActionService, player: PlayerId)
		self._calls[player] = self._now
		setAttribute(self, player, Attributes.CallingPass, true)
	end,
}

local ActionService: ActionService = {
	name = "ActionService",
	dependencies = { "Config", "NetService", "BallService", "TeamService", "CharacterService" },
	_config = nil :: any,
	_net = nil :: any,
	_ball = nil :: any,
	_teams = nil :: any,
	_characters = nil :: any,
	_speedLimit = 0,
	_now = 0,
	_records = {},
	_order = {},
	_holderList = {},
	_holderOf = {},
	_calls = {},
	_candidates = {},
	_context = { hasBall = false, airborne = false, knockedDown = false },
	_knockdowns = {},
	_knockdownPool = {},

	init = function(self: ActionService, deps: { [string]: any })
		local config: Config.GameConfig = deps.Config
		self._config = config
		self._net = deps.NetService
		self._ball = deps.BallService
		self._teams = deps.TeamService
		self._characters = deps.CharacterService
		self._speedLimit = MovementCheck.speedLimit(config.Movement, config.Network)
		self._now = 0
		self._records = {}
		self._order = {}
		self._holderList = {}
		self._holderOf = {}
		self._calls = {}
		self._candidates = {}
		-- The server never judges `airborne`: it cannot see the client's ground ray.
		self._context = { hasBall = false, airborne = false, knockedDown = false }
		self._knockdowns = {}
		self._knockdownPool = {}
		self._net:listen(
			Remotes.names.ActionRequest,
			Schemas.ActionRequest,
			config.Network.maxActionsPerSecond,
			function(player: PlayerId, payload: any)
				self:request(player, payload)
			end
		)
		self._characters.characterRemoved:Connect(function(player: PlayerId)
			self:forget(player)
		end)
		self._teams.unseated:Connect(function(player: PlayerId)
			self:forget(player)
		end)
	end,

	-- Refused when the player has no seated, living character, is frozen, or their runner says no, with
	-- Network.actionTimingTolerance of slack on its timing, for lag.
	request = function(self: ActionService, player: PlayerId, payload: any)
		local name: Config.ActionName = payload.action
		refreshHolders(self)
		local holder = self._holderOf[player]
		if holder == nil or holder.root.Anchored then
			reject(self, player, name)
			return
		end
		local record = recordOf(self, player)
		local context = self._context
		context.hasBall = self._ball.state.carrier == player
		context.knockedDown = knockedDown(self, player)
		if record.runner:start(name, context, self._config.Network.actionTimingTolerance) ~= "Started" then
			reject(self, player, name)
			return
		end
		record.struck = false
		local action = self._config.Actions[name]
		effects[action.effect](self, player, holder, payload, action)
		show(self, player, record)
	end,

	step = function(self: ActionService, dt: number): { Knockdown }
		self._now += dt
		table.clear(self._knockdowns)
		refreshHolders(self)
		local window = self._config.Actions.callPassWindow
		local carrier = self._ball.state.carrier
		for player, at in self._calls do
			if self._now - at > window or player == carrier then
				self._calls[player] = nil
				setAttribute(self, player, Attributes.CallingPass, nil)
			end
		end
		for _, player in self._order do
			local record = self._records[player]
			record.runner:step(dt)
			if record.knockdownLeft > 0 then
				record.knockdownLeft -= dt
				if record.knockdownLeft <= 0 then
					record.knockdownLeft = 0
					setAttribute(self, player, Attributes.KnockedDown, nil)
				end
			end
			show(self, player, record)
		end
		for _, player in self._order do
			aim(self, player, self._records[player])
		end
		for _, player in self._order do
			local record = self._records[player]
			local victim = record.hit
			if victim ~= nil then
				record.hit = nil
				record.struck = true
				knockDown(self, player, victim, record.hitSeconds)
			end
		end
		return self._knockdowns
	end,

	reset = function(self: ActionService)
		refreshHolders(self)
		for _, player in self._order do
			local record = self._records[player]
			record.runner:reset()
			record.struck = false
			record.hit = nil
			record.knockdownLeft = 0
			record.shown = nil
		end
		for _, holder in self._holderList do
			local character = holder.root.Parent
			if character ~= nil then
				character:SetAttribute(Attributes.Action, nil)
				character:SetAttribute(Attributes.KnockedDown, nil)
				character:SetAttribute(Attributes.CallingPass, nil)
			end
		end
		table.clear(self._calls)
	end,

	forget = function(self: ActionService, player: PlayerId)
		self._records[player] = nil
		self._calls[player] = nil
		local index = table.find(self._order, player)
		if index ~= nil then
			table.remove(self._order, index)
		end
	end,

	isImmune = function(self: ActionService, player: PlayerId): boolean
		local record = self._records[player]
		if record == nil then
			return false
		end
		local action: Config.ActionName? = record.runner.action
		return action ~= nil and record.runner.phase == "Active" and self._config.Actions[action].effect == "Dodge"
	end,
}

return ActionService
