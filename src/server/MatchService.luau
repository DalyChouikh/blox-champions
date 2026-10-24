--!strict
-- Runs matches on the server (spec §4–§5, §10), in the server's one frame order. Each frame it steps the actions first
-- (strikes, knockdowns and their drops), then the ball, then reports the ball's movement, a throw, a catch, a body
-- touch and each knockdown to the rules engine in the order the engine documents, ticks it, reacts to its events —
-- hiding and spawning the ball, clearing every action, knockdown and call at a kickoff, placing and freezing
-- characters, opening and closing the goal — and sends them to clients, each frame's batch followed by the match's
-- snapshot, which clients draw from, both marked with the frame's number. A snapshot also goes to everyone whenever a
-- seat changes, and to each player who joins, marked with the last frame's number; it names every player in the server
-- and each who left during the match, so the score tab can name them. It
-- keeps the ball dead whenever play is not live, so the ball is only ever carried by the engine's last holder. After a
-- match ends it waits postMatchSeconds and starts the next one with everyone reseated; once every player has left it
-- starts over.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ActionService = require(script.Parent.ActionService)
local ArenaService = require(script.Parent.ArenaService)
local BallService = require(script.Parent.BallService)
local CharacterService = require(script.Parent.CharacterService)
local Config = require(ReplicatedStorage.Shared.Config)
local MatchEngine = require(ReplicatedStorage.Shared.Rules.MatchEngine)
local NetService = require(script.Parent.NetService)
local Payloads = require(ReplicatedStorage.Shared.Net.Payloads)
local PlayerIds = require(ReplicatedStorage.Shared.Net.PlayerIds)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local TaggedLayout = require(ReplicatedStorage.Shared.Arena.TaggedLayout)
local Team = require(ReplicatedStorage.Shared.Rules.Team)
local TeamService = require(script.Parent.TeamService)
local Types = require(ReplicatedStorage.Shared.Rules.Types)

type PlayerId = Types.PlayerId

-- Spelled out so the module is a Loader.LoadableModule and callers see its methods.
export type MatchService = {
	name: string,
	dependencies: { string },
	init: (self: MatchService, deps: { [string]: any }) -> (),
	start: (self: MatchService) -> (),
	step: (self: MatchService, dt: number) -> (),
	engine: MatchEngine.MatchEngine,
	_config: Config.GameConfig,
	_arena: ArenaService.ArenaService,
	_net: NetService.NetService,
	_ball: BallService.BallService,
	_teams: TeamService.TeamService,
	_characters: CharacterService.CharacterService,
	_actions: ActionService.ActionService,
	-- Players the current engine knows, so only they are removed from it.
	_inEngine: { [PlayerId]: boolean },
	_waiting: boolean,
	-- Counts down after MatchEnded; nil while a match is on.
	_postMatchLeft: number?,
	_carrier: PlayerId?,
	-- The players in the server and each who left during the current match, by id: their name as the HUD shows it.
	_names: { [PlayerId]: string },
	-- The frames stepped so far: the number each batch and snapshot carries, so a client can tell which is newer.
	_frame: number,
	_nameOf: (player: PlayerId) -> string,
}

-- The arena ArenaService built at init, before this module's init ran.
local function arena(self: MatchService): TaggedLayout.TaggedArena
	return self._arena.arena :: TaggedLayout.TaggedArena
end

-- An open goal lets the ball through its panel; each client slides the panel out of the ring (ArenaGlow).
local function setGoalOpen(self: MatchService, open: boolean)
	local panel = arena(self).goalPanel
	panel.CanCollide = not open
	panel.CanQuery = not open
end

local function newEngine(self: MatchService)
	self.engine = MatchEngine.new({
		config = self._config,
		arena = arena(self).layout,
		gravity = Vector3.new(0, -workspace.Gravity, 0),
	})
	self._inEngine = {}
	self._waiting = true
	self._postMatchLeft = nil
	-- A new match lists only the players in the server, so the names sent with each snapshot stop at them.
	local names = self._names
	for player in names do
		if not self._teams:has(player) then
			names[player] = nil
		end
	end
	-- A new engine's goal is closed; the panel must say so even if the last match ended with it open.
	setGoalOpen(self, false)
end

-- The match as clients draw it, to `to`, or to everyone.
local function sendSnapshot(self: MatchService, to: PlayerId?)
	local payload: Payloads.MatchSnapshot = { frame = self._frame, match = self.engine:snapshot(), names = self._names }
	if to ~= nil then
		self._net:fireTo(to, Remotes.names.MatchSnapshot, payload)
	else
		self._net:fireAll(Remotes.names.MatchSnapshot, payload)
	end
end

local function dropIfCarrier(self: MatchService, player: PlayerId)
	if self._ball.state.carrier == player then
		self._ball:drop()
	end
end

local function react(self: MatchService, event: Types.Event)
	local name = event.name
	if name == "KickoffStarted" then
		self._ball:hide()
		self._actions:reset()
		self._characters:placeAll(true)
	elseif name == "KickoffEnded" then
		self._ball:spawn()
		self._characters:freezeAll(false)
	elseif name == "GoalOpened" then
		setGoalOpen(self, true)
	elseif name == "GoalClosed" then
		setGoalOpen(self, false)
	elseif name == "GoalScored" or name == "StreakPointScored" then
		self._ball:kill()
	elseif name == "MatchEnded" then
		self._ball:kill()
		self._postMatchLeft = self._config.Match.postMatchSeconds
	end
end

local function nextMatch(self: MatchService)
	newEngine(self)
	self._ball:hide()
	-- Reseating announces every seat, which adds each player to the new engine.
	self._teams:newMatch()
	sendSnapshot(self)
end

local MatchService: MatchService = {
	name = "MatchService",
	dependencies = {
		"Config",
		"ArenaService",
		"NetService",
		"BallService",
		"TeamService",
		"CharacterService",
		"ActionService",
	},
	engine = nil :: any,
	_config = nil :: any,
	_arena = nil :: any,
	_net = nil :: any,
	_ball = nil :: any,
	_teams = nil :: any,
	_characters = nil :: any,
	_actions = nil :: any,
	_inEngine = {},
	_waiting = true,
	_postMatchLeft = nil,
	_carrier = nil,
	_names = {},
	_frame = 0,
	_nameOf = function(player: PlayerId): string
		return player
	end,

	-- deps.NameOf replaces the players' display names in tests.
	init = function(self: MatchService, deps: { [string]: any })
		self._config = deps.Config
		self._arena = deps.ArenaService
		self._net = deps.NetService
		self._ball = deps.BallService
		self._teams = deps.TeamService
		self._characters = deps.CharacterService
		self._actions = deps.ActionService
		self._carrier = nil
		self._names = {}
		self._frame = 0
		self._nameOf = deps.NameOf
			or function(player: PlayerId): string
				local roblox = PlayerIds.player(player)
				return if roblox ~= nil then roblox.DisplayName else player
			end
		newEngine(self)

		self._teams.joined:Connect(function(player: PlayerId)
			self._names[player] = self._nameOf(player)
			sendSnapshot(self, player)
			local carrier: Payloads.BallCarrier = { carrier = self._carrier }
			self._net:fireTo(player, Remotes.names.BallCarrier, carrier)
		end)
		self._teams.seated:Connect(function(player: PlayerId, team: Team.Team)
			-- After the match the next one seats everyone.
			if self._postMatchLeft == nil then
				self.engine:addPlayer(player, team)
				self._inEngine[player] = true
			end
			sendSnapshot(self)
		end)
		self._teams.unseated:Connect(function(player: PlayerId)
			dropIfCarrier(self, player)
			if self._inEngine[player] then
				self.engine:removePlayer(player)
				self._inEngine[player] = nil
			end
			-- Nobody left to play: the next player starts a fresh match instead of joining an abandoned one.
			if self._teams:seatedCount() == 0 and not self._waiting then
				newEngine(self)
				self._ball:hide()
			end
			sendSnapshot(self)
		end)
		self._characters.characterRemoved:Connect(function(player: PlayerId)
			dropIfCarrier(self, player)
		end)
	end,

	start = function(self: MatchService)
		RunService.Heartbeat:Connect(function(dt: number)
			self:step(dt)
		end)
	end,

	-- One server frame: the actions first (strikes, knockdowns and their drops, before the ball moves), then the ball,
	-- then the engine's facts in its order (ballMoved, thrown, pickedUp, touched, knockedDown), tick, and the drained
	-- events.
	step = function(self: MatchService, dt: number)
		self._frame += 1
		local engine = self.engine
		if self._waiting and self._teams:seatedCount() >= self._config.Match.minPlayersToStart then
			self._waiting = false
			engine:start()
		end

		local knockdowns = self._actions:step(dt)
		local frame = self._ball:step(dt, self._characters:holders())
		if frame.moved then
			engine:ballMoved(frame.from, frame.to)
		end
		if frame.thrower ~= nil then
			engine:thrown(frame.thrower)
		end
		if frame.picker ~= nil then
			engine:pickedUp(frame.picker, frame.pickupPosition, frame.pickupVelocity)
		end
		if frame.toucher ~= nil then
			engine:touched(frame.toucher, frame.touchPosition, frame.touchVelocity)
		end
		for _, knockdown in knockdowns do
			engine:knockedDown(knockdown.attacker, knockdown.victim)
		end
		engine:tick(dt)

		-- Sent before the reactions, so one that fails cannot keep the frame's events or its snapshot from the clients.
		local events = engine:drainEvents()
		if #events > 0 then
			local batch: Payloads.RuleEvents = { frame = self._frame, events = events }
			self._net:fireAll(Remotes.names.RuleEvents, batch)
			sendSnapshot(self)
			for _, event in events do
				react(self, event)
			end
		end

		local carrier: PlayerId? = self._ball.state.carrier
		if carrier ~= self._carrier then
			self._carrier = carrier
			local told: Payloads.BallCarrier = { carrier = carrier }
			self._net:fireAll(Remotes.names.BallCarrier, told)
		end

		local postMatchLeft = self._postMatchLeft
		if postMatchLeft ~= nil then
			postMatchLeft -= dt
			self._postMatchLeft = postMatchLeft
			if postMatchLeft <= 0 then
				nextMatch(self)
			end
		end
	end,
}

return MatchService
